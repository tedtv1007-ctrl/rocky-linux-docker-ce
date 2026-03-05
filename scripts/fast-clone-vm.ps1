<#
.SYNOPSIS
    Fast clones a VM by copying the VHDX file.
    Faster than Export/Import.
#>

param (
    [string]$SourceVMName = "Lab-VM1-Mgmt",
    [string]$NewVMName = "Lab-VM3-Node2",
    [string]$VMBasePath = "C:\Hyper-V\EnterpriseLab"
)

# 1. 取得來源 VM 硬體配置 (不含磁碟)
$sourceVM = Get-VM -Name $SourceVMName -ErrorAction Stop
if ($sourceVM.State -ne "Off") { Write-Error "Source VM must be OFF!"; exit }

$SourceVHDPath = (Get-VMHardDiskDrive -VMName $SourceVMName).Path
$NewVMDir = Join-Path $VMBasePath $NewVMName
$NewVHDPath = Join-Path $NewVMDir "$NewVMName.vhdx"

# 取得來源使用的 Switch 名稱
$SwitchName = (Get-VMNetworkAdapter -VMName $SourceVMName).SwitchName

# 2. 建立新資料夾並複製 VHDX
if (!(Test-Path $NewVMDir)) { New-Item -ItemType Directory -Path $NewVMDir -Force }
Write-Host "Copying VHDX to $NewVHDPath... (Fast Copy)" -ForegroundColor Cyan
Copy-Item -Path $SourceVHDPath -Destination $NewVHDPath

# 3. 建立新虛擬機 (繼承來源規格)
Write-Host "Creating new VM '$NewVMName'..." -ForegroundColor Cyan
$newVM = New-VM -Name $NewVMName -MemoryStartupBytes $sourceVM.MemoryStartup -Generation $sourceVM.Generation -Path $VMBasePath -SwitchName $SwitchName

# 設定規格
Set-VMProcessor -VMName $NewVMName -Count $sourceVM.ProcessorCount
Set-VMMemory -VMName $NewVMName -DynamicMemoryEnabled $false

# 掛載複製好的硬碟
Add-VMHardDiskDrive -VMName $NewVMName -Path $NewVHDPath

Write-Host "Fast Clone Complete!" -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Yellow
Write-Host "⚠️ IMPORTANT NEXT STEPS FOR ROCKY LINUX CLONES ⚠️" -ForegroundColor Yellow
Write-Host "1. Start the VM: Start-VM -Name $NewVMName" -ForegroundColor Cyan
Write-Host "2. Connect to the VM console and log in." -ForegroundColor Cyan
Write-Host "3. Upload and run the identity reset script to prevent network conflicts:" -ForegroundColor Cyan
Write-Host "   ./scripts/reset-vm-identity.sh <new-hostname> <new-ip>" -ForegroundColor White
Write-Host "   Example: ./scripts/reset-vm-identity.sh $NewVMName 192.168.100.21" -ForegroundColor White
Write-Host "====================================================================" -ForegroundColor Yellow
