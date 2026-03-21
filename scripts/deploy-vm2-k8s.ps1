<#
.SYNOPSIS
    Deploys Kubernetes Node components to Lab-VM2-K8S.
    This version bypasses Ansible for maximum reliability on Rocky Linux 10.
#>

# Load Configuration
$ConfigPath = "$PSScriptRoot\lab-config.json"
if (!(Test-Path $ConfigPath)) { Write-Error "Configuration file not found: $ConfigPath"; exit }
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$TargetVM = $Config.VMs | Where-Object { $_.Role -eq "K8S-Node" }
if (!$TargetVM) { Write-Error "Target VM with Role 'K8S-Node' not found in config."; exit }

$VM_IP = $TargetVM.IP
$SSH_USER = $Config.Credentials.DefaultUser
$SSH_PASS = $Config.Credentials.DefaultPass
$BootstrapScript = "$PSScriptRoot\bootstrap-k8s-rocky.sh"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " K8S Node Automated Deployer (Fast Bootstrap)" -ForegroundColor Cyan
Write-Host " Target VM: $VM_IP ($SSH_USER)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$SSH_OPTS = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null")

# 1. Upload Bootstrap Scripts
Write-Host "Step 1: Uploading Bootstrap and Cilium scripts..." -ForegroundColor Cyan
scp $SSH_OPTS "$BootstrapScript" "${SSH_USER}@${VM_IP}:~/bootstrap-k8s.sh"
scp $SSH_OPTS "$PSScriptRoot\install-cilium.sh" "${SSH_USER}@${VM_IP}:~/install-cilium.sh"

# 2. Execute Bootstrap Script
Write-Host "Step 2: Executing K8S Bootstrap (this may take 2-3 minutes)..." -ForegroundColor Cyan
# Fix potential CRLF issues and execute bootstrap
$remoteCmd = "sed -i 's/\r$//' ~/bootstrap-k8s.sh ~/install-cilium.sh && chmod +x ~/bootstrap-k8s.sh ~/install-cilium.sh && sudo bash ~/bootstrap-k8s.sh"
ssh $SSH_OPTS -t $SSH_USER@$VM_IP $remoteCmd

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " K8S Node Preparation Completed!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Next Step: You can now initialize the cluster on VM2."
Write-Host "Log into VM2: ssh sysadmin@$VM_IP" -ForegroundColor Yellow
Write-Host "And run: sudo kubeadm init --pod-network-cidr=10.244.0.0/16" -ForegroundColor Yellow
