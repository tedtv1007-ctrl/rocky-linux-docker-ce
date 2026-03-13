<#
.SYNOPSIS
    Deploys Kubernetes Node components (Containerd, Kubeadm, Kubelet) to Lab-VM2-K8S via Ansible.
    This script runs on the Windows host.
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

$AnsibleSrcDir = "$PSScriptRoot\..\ansible"
$RemoteTmpDir = "/home/$SSH_USER/ansible-deploy"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " K8S Node Automated Deployer (via Ansible)" -ForegroundColor Cyan
Write-Host " Target VM: $VM_IP ($SSH_USER)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. SSH Environment Preparation
Write-Host "Cleaning up old SSH known_hosts for $VM_IP..." -ForegroundColor Gray
ssh-keygen -R $VM_IP 2>$null | Out-Null

$SSH_OPTS = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null")

# 1. Setup SSH Key authentication
$PubKeyFile = "$HOME\.ssh\id_rsa.pub"
if (-not (Test-Path "$HOME\.ssh\id_rsa")) {
    Write-Host "Generating SSH Key for passwordless login..." -ForegroundColor Cyan
    ssh-keygen -t rsa -b 4096 -N '""' -f "$HOME\.ssh\id_rsa" | Out-Null
}

$PubKey = (Get-Content $PubKeyFile -Raw).Trim()
Write-Host "`n[ACTION REQUIRED] Setting up passwordless login." -ForegroundColor Yellow
Write-Host "Please type the password " -NoNewline
Write-Host "'$SSH_PASS'" -ForegroundColor Green -NoNewline
Write-Host " to authenticate." -ForegroundColor Yellow

ssh $SSH_OPTS -t $SSH_USER@$VM_IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

Write-Host "`nPasswordless SSH configured successfully! Moving to automation...`n" -ForegroundColor Green

# 2. Cleanup and Create remote directory (in HOME, not /tmp)
Write-Host "Step 1: Preparing remote directory..."
ssh $SSH_OPTS -t $SSH_USER@$VM_IP "rm -rf $RemoteTmpDir; mkdir -p $RemoteTmpDir; chmod 700 $RemoteTmpDir"

# 3. Upload Ansible playbooks and configs
Write-Host "Step 2: Uploading Ansible Playbooks..."
scp $SSH_OPTS -r "$AnsibleSrcDir" "${SSH_USER}@${VM_IP}:$RemoteTmpDir/"
# Ensure all files within the deploy dir are secure
ssh $SSH_OPTS -t $SSH_USER@$VM_IP "chmod -R 700 $RemoteTmpDir"

# 4. Install Ansible locally on the VM
Write-Host "Step 3: Installing Ansible core on VM2..."
ssh $SSH_OPTS -t $SSH_USER@$VM_IP "sudo dnf install -y 'dnf-command(config-manager)' && sudo dnf config-manager --set-enabled crb && sudo dnf install epel-release -y -q && sudo dnf install ansible-core -y -q"

# 5. Execute Ansible Playbook
Write-Host "Step 4: Executing Ansible Playbook for K8S Node Setup..."

# Execute playbook locally on the node (now 100% builtin dependencies)
$ansibleCmd = "cd $RemoteTmpDir/ansible && sudo ansible-playbook -i 127.0.0.1, -c local playbooks/k8s-node-setup.yml"
ssh $SSH_OPTS -t $SSH_USER@$VM_IP $ansibleCmd

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " K8S Node Preparation Completed!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Next Step: You can now initialize the cluster on VM2."
Write-Host "Log into VM2: ssh sysadmin@$VM_IP" -ForegroundColor Yellow
Write-Host "And run: sudo kubeadm init --pod-network-cidr=10.244.0.0/16" -ForegroundColor Yellow
