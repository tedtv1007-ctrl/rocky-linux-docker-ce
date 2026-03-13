<#
.SYNOPSIS
    Automates the creation of Hyper-V VMs for the Enterprise Containerization Lab using Cloud-Init (Infrastructure as Code).
    Target OS: Rocky Linux 9 Generic Cloud (Cloud-Init ready).
    REQUIREMENT: Must run as Administrator.
#>

# Load Configuration
$ConfigPath = "$PSScriptRoot\lab-config.json"
if (!(Test-Path $ConfigPath)) { Write-Error "Configuration file not found: $ConfigPath"; exit }
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$SwitchName = $Config.Network.SwitchName
$BaseVhdxPath = "$PSScriptRoot\$($Config.Storage.BaseVhdxName)"
$VMPath = $Config.Storage.VMPath

# Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " ERROR: This script MUST be run as Administrator!" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    exit
}

# 1. Ensure Directories exist
if (!(Test-Path $VMPath)) { 
    Write-Host "Creating directory $VMPath..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $VMPath -Force 
}

# 2. Virtual Switch setup
$ExistingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (!$ExistingSwitch) {
    Write-Host "Creating Virtual Switch: $SwitchName..." -ForegroundColor Cyan
    try {
        New-VMSwitch -Name $SwitchName -SwitchType Internal -ErrorAction Stop
        Start-Sleep -Seconds 2
        $NetAdapter = Get-NetAdapter -Name "vEthernet ($SwitchName)"
        $NetAdapter | New-NetIPAddress -IPAddress $Config.Network.Gateway -PrefixLength 24 -ErrorAction SilentlyContinue

        # Add NAT for Internet Access
        Write-Host "Configuring NAT for $($Config.Network.Subnet)..." -ForegroundColor Cyan
        Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
        New-NetNat -Name "K8S-Internal-NAT" -InternalIPInterfaceAddressPrefix $Config.Network.Subnet -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to create Virtual Switch. Error: $($_.Exception.Message)"
        exit
    }
}

# 3. Prepare Rocky Linux VHDX Image
if (!(Test-Path $BaseVhdxPath)) {
    Write-Host "Base VHDX not found. Running preparation script..." -ForegroundColor Yellow
    & "$PSScriptRoot\prepare-base-vhdx.ps1"
    
    if (!(Test-Path $BaseVhdxPath)) {
        Write-Error "Base VHDX preparation failed. Cannot continue."
        exit
    }
} else {
    Write-Host "Found existing Base VHDX: $BaseVhdxPath." -ForegroundColor Green
}

# 4. Define VM Specifications
$VMs = $Config.VMs

foreach ($vm in $VMs) {
    if (!(Get-VM -Name $vm.Name -ErrorAction SilentlyContinue)) {
        Write-Host "Provisioning VM: $($vm.Name) with Cloud-Init..." -ForegroundColor Cyan
        
        # Convert RAM string (e.g., "4GB") to Bytes for New-VM
        $RAMBytes = 4GB # Default fallback
        if ($vm.RAM -match "^(\d+)(KB|MB|GB|TB)$") {
            $value = [long]$Matches[1]
            $unit = $Matches[2]
            switch ($unit) {
                "KB" { $RAMBytes = $value * 1KB }
                "MB" { $RAMBytes = $value * 1MB }
                "GB" { $RAMBytes = $value * 1GB }
                "TB" { $RAMBytes = $value * 1TB }
            }
        } elseif ($vm.RAM -as [long]) {
            $RAMBytes = [long]$vm.RAM
        }

        $VMDir = "$VMPath\$($vm.Name)"
        if (!(Test-Path $VMDir)) { New-Item -ItemType Directory -Path $VMDir | Out-Null }
        
        $OSDisk = "$VMDir\$($vm.Name)-os.vhdx"
        $SeedDisk = "$VMDir\$($vm.Name)-seed.vhdx"
        
        # Copy base VHDX for OS
        if (Test-Path $OSDisk) { Remove-Item -Path $OSDisk -Force }
        Copy-Item -Path $BaseVhdxPath -Destination $OSDisk -Force

        # Generate CIDATA Seed VHDX for Cloud-Init
        Write-Host "  -> Creating Cloud-Init Seed VHDX (64MB)..."
        if (Test-Path $SeedDisk) { Remove-Item -Path $SeedDisk -Force }
        New-VHD -Path $SeedDisk -SizeBytes 64MB -Dynamic | Out-Null
        $Mount = Mount-VHD -Path $SeedDisk -PassThru
        $Disk = Get-Disk -Number $Mount.DiskNumber
        Initialize-Disk -Number $Disk.Number -PartitionStyle MBR
        # Prevent 'Format Disk' prompt by NOT assigning a drive letter to RAW partition
        $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -IsActive -AssignDriveLetter:$false
        Format-Volume -Partition $Partition -FileSystem FAT32 -NewFileSystemLabel "CIDATA" -Confirm:$false | Out-Null
        
        # Safely bind an available drive letter after formatting
        $TakenLetters = (Get-Volume).DriveLetter | Where-Object { $_ }
        $DriveLetter = (69..90 | ForEach-Object { [char]$_ } | Where-Object { $TakenLetters -notcontains $_ }) | Select-Object -First 1
        Set-Partition -DiskNumber $Disk.Number -PartitionNumber $Partition.PartitionNumber -NewDriveLetter $DriveLetter | Out-Null
        Start-Sleep -Seconds 1

$MetaData = @"
instance-id: $($vm.Name)
local-hostname: $($vm.Name)
"@
Set-Content -Path "$($DriveLetter):\meta-data" -Value $MetaData -Encoding ASCII

$UserData = @"
#cloud-config
users:
  - default
  - name: $($Config.Credentials.DefaultUser)
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    shell: /bin/bash
    lock_passwd: false

chpasswd:
  list: |
    root:$($Config.Credentials.RootPass)
    $($Config.Credentials.DefaultUser):$($Config.Credentials.DefaultPass)
  expire: false

ssh_pwauth: true

runcmd:
  - systemctl restart NetworkManager
"@
Set-Content -Path "$($DriveLetter):\user-data" -Value $UserData -Encoding ASCII

$NetworkConfig = @"
version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - $($vm.IP)/24
    gateway4: $($Config.Network.Gateway)
    nameservers:
      addresses:
$( $Config.Network.DnsServers | ForEach-Object { "        - $_" } | Out-String )
"@
Set-Content -Path "$($DriveLetter):\network-config" -Value $NetworkConfig -Encoding ASCII

        Dismount-VHD -Path $SeedDisk
        
        # Create VM (Generation 2)
        $newVM = New-VM -Name $vm.Name -MemoryStartupBytes $RAMBytes -Generation 2 -Path $VMPath -SwitchName $SwitchName
        
        Set-VMProcessor -VMName $vm.Name -Count $vm.CPU
        Set-VMMemory -VMName $vm.Name -DynamicMemoryEnabled $true -MinimumBytes 1GB -MaximumBytes $RAMBytes
        Set-VM -Name $vm.Name -CheckpointType Disabled
        Set-VMFirmware -VMName $vm.Name -EnableSecureBoot Off
        
        # Attach OS and Seed Disks
        Add-VMHardDiskDrive -VMName $vm.Name -Path $OSDisk
        Add-VMHardDiskDrive -VMName $vm.Name -Path $SeedDisk
        
        # Adjust boot order to OS Disk
        $hdd = Get-VMHardDiskDrive -VMName $vm.Name | Where-Object Path -match "-os.vhdx$"
        try { Set-VMBootOrder -VMName $vm.Name -FirstInOrder $hdd } catch {}
        
        Write-Host "VM $($vm.Name) provisioned! (IP: $($vm.IP), Credentials: $($Config.Credentials.DefaultUser) / $($Config.Credentials.DefaultPass))" -ForegroundColor Green
    } else {
        Write-Host "VM $($vm.Name) already exists, skipping." -ForegroundColor Yellow
    }
}

Write-Host "`nAll VMs prepared via Cloud-Init! You can now start them in Hyper-V Manager." -ForegroundColor Green
Write-Host "The VMs will configure their own IP and Users automatically upon first boot." -ForegroundColor Cyan
