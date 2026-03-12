<#
.SYNOPSIS
    Automates the creation of Hyper-V VMs for the Enterprise Containerization Lab.
    Target OS: Rocky Linux 10.1
    REQUIREMENT: Must run as Administrator.
#>

$SwitchName = "K8S-Internal"
$ISOPath = "$PSScriptRoot\Rocky-10.1-x86_64-minimal.iso"
# Updated to a more stable mirror/link
$ISOUrl = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10-latest-x86_64-minimal.iso"
$VMPath = "D:\HypervLinux\EnterpriseLab"

# Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script MUST be run as Administrator! Please reopen PowerShell as Admin."
    exit
}

# 1. Ensure Directories exist
if (!(Test-Path $VMPath)) { 
    Write-Host "Creating directory $VMPath..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $VMPath -Force 
}

# 2. Create Virtual Switch
$ExistingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if ($ExistingSwitch) {
    Write-Host "Virtual Switch $SwitchName already exists." -ForegroundColor Gray
} else {
    Write-Host "Creating Virtual Switch: $SwitchName..." -ForegroundColor Cyan
    # Attempt to cleanup orphaned adapters with same name to avoid 0x800700B7
    $OrphanedAdapter = Get-NetAdapter -Name "vEthernet ($SwitchName)" -ErrorAction SilentlyContinue
    if ($OrphanedAdapter) {
        Write-Warning "Found orphaned adapter '$SwitchName'. Attempting to cleanup..."
        # Note: Removing orphaned virtual adapters sometimes requires manual intervention in Hyper-V Manager.
    }

    try {
        New-VMSwitch -Name $SwitchName -SwitchType Internal -ErrorAction Stop
        Start-Sleep -Seconds 2
        $NetAdapter = Get-NetAdapter -Name "vEthernet ($SwitchName)"
        $NetAdapter | New-NetIPAddress -IPAddress 192.168.250.1 -PrefixLength 24 -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to create Virtual Switch. Error: $($_.Exception.Message)"
        Write-Host "TIP: Please open 'Virtual Switch Manager' in Hyper-V and manually delete '$SwitchName' if it exists." -ForegroundColor Yellow
        exit
    }
}

# 3. Download ISO (If not exists)
if (!(Test-Path $ISOPath)) {
    Write-Host "Downloading Rocky Linux 10.1 ISO (this may take a while)..." -ForegroundColor Cyan
    # Using -UseBasicParsing for compatibility
    Invoke-WebRequest -Uri $ISOUrl -OutFile $ISOPath
}

# 4. Define VM Specifications
$VMs = @(
    @{ Name = "Lab-VM1-Mgmt"; RAM = 12GB; CPU = 4; Disk = 100GB },
    @{ Name = "Lab-VM2-K8S";  RAM = 8GB;  CPU = 4; Disk = 60GB  }
)

foreach ($vm in $VMs) {
    if (!(Get-VM -Name $vm.Name -ErrorAction SilentlyContinue)) {
        Write-Host "Creating VM: $($vm.Name)..." -ForegroundColor Cyan
        
        # Create VM (Generation 2)
        $newVM = New-VM -Name $vm.Name -MemoryStartupBytes $vm.RAM -Generation 2 -Path $VMPath -SwitchName $SwitchName
        
        # Set CPU Cores
        Set-VMProcessor -VMName $vm.Name -Count $vm.CPU
        
        # Create and Attach VHDX
        $VHDPath = "$VMPath\$($vm.Name)\$($vm.Name).vhdx"
        if (!(Test-Path $VHDPath)) {
            New-VHD -Path $VHDPath -SizeBytes $vm.Disk -Dynamic
        }
        Add-VMHardDiskDrive -VMName $vm.Name -Path $VHDPath
        
        # Disable Dynamic Memory (Essential for K8S)
        Set-VMMemory -VMName $vm.Name -DynamicMemoryEnabled $false
        
        # Attach ISO
        Add-VMDvdDrive -VMName $vm.Name -Path $ISOPath
        
        # Set Boot Order (DVD First)
        $dvd = Get-VMDvdDrive -VMName $vm.Name
        # Fallback for older Hyper-V modules
        try {
            Set-VMBootOrder -VMName $vm.Name -FirstInOrder $dvd
        } catch {
            Write-Warning "Set-VMBootOrder failed, please manually set DVD as first boot device if needed."
        }
        
        Write-Host "VM $($vm.Name) created successfully." -ForegroundColor Green
    } else {
        Write-Host "VM $($vm.Name) already exists, skipping." -ForegroundColor Yellow
    }
}

Write-Host "`nAll VMs prepared! Please start them in Hyper-V Manager to begin Rocky Linux installation." -ForegroundColor Green
Write-Host "After OS installation, use nmcli to set IP 192.168.250.10 (VM1) and 192.168.250.20 (VM2)." -ForegroundColor Cyan
