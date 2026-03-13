<#
.SYNOPSIS
    Downloads a Rocky Linux QCOW2 cloud image and converts it to a Hyper-V VHDX using qemu-img.
#>

$BaseQcow2Path = "$PSScriptRoot\Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
$BaseVhdxPath = "$PSScriptRoot\Rocky-9-Cloud-Base.vhdx"
$QCOWUrl = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
$QemuImgZip = "$PSScriptRoot\qemu-img.zip"
$QemuImgDir = "$PSScriptRoot\qemu-img"
$QemuImgExe = "$QemuImgDir\qemu-img.exe"
$QemuImgUrl = "https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Prepare Base VHDX Image" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (!(Test-Path $BaseVhdxPath)) {
    if (!(Test-Path $QemuImgExe)) {
        Write-Host "Downloading qemu-img tool for Windows..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $QemuImgUrl -OutFile $QemuImgZip -UseBasicParsing
        Expand-Archive -Path $QemuImgZip -DestinationPath $QemuImgDir -Force
    }

    $downloadNeeded = $true
    if (Test-Path $BaseQcow2Path) {
        $fileSize = (Get-Item $BaseQcow2Path).Length
        if ($fileSize -gt 600MB) {
            $downloadNeeded = $false
        } else {
            Write-Host "Incomplete QCOW2 file found. Removing it..." -ForegroundColor Yellow
            Remove-Item $BaseQcow2Path -Force
        }
    }

    if ($downloadNeeded) {
        Write-Host "Downloading Rocky Linux Cloud Image (QCOW2) (using curl for stability)..." -ForegroundColor Cyan
        curl.exe -L -o $BaseQcow2Path $QCOWUrl
    }

    Write-Host "Converting QCOW2 to Hyper-V VHDX Format..." -ForegroundColor Cyan
    & $QemuImgExe convert -f qcow2 -O vhdx -o subformat=dynamic $BaseQcow2Path $BaseVhdxPath
    
    if ($LASTEXITCODE -eq 0 -and (Test-Path $BaseVhdxPath)) {
        Write-Host "Successfully generated: $BaseVhdxPath" -ForegroundColor Green
    } else {
        Write-Error "Failed to convert image."
    }
} else {
    Write-Host "Found existing Base VHDX: $BaseVhdxPath. Skipping download and conversion." -ForegroundColor Green
}
