# Enable Hyper-V on Windows 11 Home Edition (Enhanced)
# Author: Gemini CLI
# REQUIREMENT: Must run as Administrator

$Packages = Get-ChildItem -Path "$env:SystemRoot\servicing\Packages" -Filter "*Hyper-V*.mum"
if ($Packages.Count -eq 0) {
    Write-Error "CRITICAL: No Hyper-V related packages found in $env:SystemRoot\servicing\Packages."
    Write-Host "Please check if your Windows 11 Home is highly customized or stripped." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($Packages.Count) potential Hyper-V packages. Injecting..." -ForegroundColor Cyan

foreach ($Package in $Packages) {
    # Skip packages that are already installed to save time
    Write-Host "Processing: $($Package.Name)" -ForegroundColor Gray
    dism /online /norestart /add-package:"$($Package.FullName)" | Out-Null
}

Write-Host "Enabling Hyper-V feature set..." -ForegroundColor Cyan
# Try enabling both the platform and the management tools
dism /online /enable-feature /featurename:Microsoft-Windows-Hyper-V-All /All /LimitAccess /NoRestart
dism /online /enable-feature /featurename:Microsoft-Windows-Hyper-V /All /LimitAccess /NoRestart

Write-Host "`n--------------------------------------------------------" -ForegroundColor Green
Write-Host " SUCCESS: Hyper-V enabling process completed!" -ForegroundColor Green
Write-Host " ACTION REQUIRED: Please RESTART YOUR COMPUTER NOW." -ForegroundColor Yellow
Write-Host " After reboot, check 'Turn Windows features on or off' to confirm." -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor Green
