<#
.SYNOPSIS
    Deploys GitLab Omnibus and Harbor Registry to Lab-VM1-Mgmt via Ansible.
    This script runs on the Windows host. It securely uploads the Ansible playbooks and certificates
    to the Linux VM, temporarily installs Ansible locally on the VM, and triggers the deployment.
#>

# Load Configuration
$ConfigPath = "$PSScriptRoot\lab-config.json"
if (!(Test-Path $ConfigPath)) { Write-Error "Configuration file not found: $ConfigPath"; exit }
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$TargetVM = $Config.VMs | Where-Object { $_.Role -eq "Management" }
if (!$TargetVM) { Write-Error "Target VM with Role 'Management' not found in config."; exit }

$VM_IP = $TargetVM.IP
$SSH_USER = $Config.Credentials.DefaultUser
$SSH_PASS = $Config.Credentials.DefaultPass

$AnsibleSrcDir = "$PSScriptRoot\../ansible"
$RemoteTmpDir = "/home/$SSH_USER/ansible-deploy"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " GitLab & Harbor Automated Deployer (via Ansible)" -ForegroundColor Cyan
Write-Host " Target VM: $VM_IP ($SSH_USER)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
# 1. SSH Environment Preparation
Write-Host "Cleaning up old SSH known_hosts for $VM_IP..." -ForegroundColor Gray
ssh-keygen -R $VM_IP 2>$null | Out-Null

$SSH_OPTS = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null")

# 1. Provide warning regarding company certificates
$certFiles = Get-ChildItem -Path "$AnsibleSrcDir\certs" -File
if ($certFiles.Count -eq 0) {
    Write-Host "`n[INFO] No company certificates found in ansible/certs/. The deployment will automatically generate Self-Signed certificates for testing.`n" -ForegroundColor Yellow
} else {
    Write-Host "`n[INFO] Found certificates in ansible/certs/. These will be injected into the services.`n" -ForegroundColor Green
}

# Ensure sshpass is available (Windows does not have sshpass, so we'll instruct the user)
Write-Host "This script utilizes native Windows OpenSSH."

# 1.5 Setup SSH Key authentication
$PubKeyFile = "$HOME\.ssh\id_rsa.pub"
if (-not (Test-Path "$HOME\.ssh\id_rsa")) {
    Write-Host "Generating SSH Key for passwordless login..." -ForegroundColor Cyan
    ssh-keygen -t rsa -b 4096 -N '""' -f "$HOME\.ssh\id_rsa" | Out-Null
}

$PubKey = (Get-Content $PubKeyFile -Raw).Trim()
Write-Host "`n[ACTION REQUIRED] Setting up passwordless login." -ForegroundColor Yellow
Write-Host "Please type the password " -NoNewline
Write-Host "'$SSH_PASS'" -ForegroundColor Green -NoNewline
Write-Host " ONE LAST TIME." -ForegroundColor Yellow

ssh -t $SSH_OPTS $SSH_USER@$VM_IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

Write-Host "`nPasswordless SSH configured successfully! Moving to automation...`n" -ForegroundColor Green

# 2. Cleanup and Create remote directory (in HOME, not /tmp)
Write-Host "Step 1: Preparing remote directory..."
ssh $SSH_OPTS -t $SSH_USER@$VM_IP "rm -rf $RemoteTmpDir; mkdir -p $RemoteTmpDir; chmod 700 $RemoteTmpDir"

# 3. Upload Ansible playbooks and configs
Write-Host "Step 2: Uploading Ansible Playbooks and Certs..."
scp $SSH_OPTS -r "$AnsibleSrcDir" "${SSH_USER}@${VM_IP}:$RemoteTmpDir/"
# Ensure all files within the deploy dir are secure
ssh $SSH_OPTS -t $SSH_USER@$VM_IP "chmod -R 700 $RemoteTmpDir"
# Certs still need to be accessible via /tmp/certs for omnibus installer
ssh $SSH_OPTS -t $SSH_USER@$VM_IP "sudo rm -rf /tmp/certs; sudo mkdir -p /tmp/certs; sudo cp -r $RemoteTmpDir/ansible/certs/* /tmp/certs/ 2>/dev/null || true"

# 4. Install Ansible locally on the VM
Write-Host "Step 3: Installing Ansible core on VM1..."
ssh $SSH_OPTS -t $SSH_USER@$VM_IP "sudo dnf install -y 'dnf-command(config-manager)' && sudo dnf config-manager --set-enabled crb && sudo dnf install epel-release -y -q && sudo dnf install ansible-core -y -q"

# 5. Execute Ansible Playbook
Write-Host "Step 4: Executing Ansible Playbook for GitLab and Harbor..."
Write-Host "This process will take 10-15 minutes. DO NOT close this window.`n" -ForegroundColor Yellow

# Execute playbook locally on the node (now 100% builtin dependencies)
$ansibleCmd = "cd $RemoteTmpDir/ansible && sudo ansible-playbook -i 127.0.0.1, -c local playbooks/vm1-master-setup.yml"
ssh $SSH_OPTS -t $SSH_USER@$VM_IP $ansibleCmd

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Deployment Completed!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Please update your Windows Host file (C:\Windows\System32\drivers\etc\hosts):"
Write-Host "$VM_IP gitlab.it205.ski.ad harbor.it205.ski.ad" -ForegroundColor Yellow
Write-Host "`nYou can then access:"
Write-Host "- GitLab: https://gitlab.it205.ski.ad  (Root Default Password: <Check VM /etc/gitlab/initial_root_password>)"
Write-Host "- Harbor: https://harbor.it205.ski.ad  (Default User: admin / Harbor12345)"
