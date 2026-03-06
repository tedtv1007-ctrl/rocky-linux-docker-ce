# VM1 Control Plane Installation Guide (GitLab + Harbor)

This document details the installation process for GitLab Omnibus and Harbor on VM1 (Rocky Linux 10.1).

## 1. Prerequisites
- OS: Rocky Linux 10.1
- Network: Static IP (e.g., 192.168.100.10)
- FQDNs: `gitlab.it205.ski.ad`, `harbor.it205.ski.ad`
- Certificates: AD CS Root CA trusted, Leaf certificates issued.

## 2. GitLab Omnibus Installation
### Install Dependencies
```bash
sudo dnf install -y curl policycoreutils openssh-server perl
sudo systemctl enable sshd
sudo systemctl start sshd
```

### Install GitLab
```bash
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | sudo bash
sudo EXTERNAL_URL="https://gitlab.it205.ski.ad" dnf install -y gitlab-ee
```

### Configure TLS (AD CS)
1. Place certificates in `/etc/gitlab/ssl/`:
   - `gitlab.it205.ski.ad.crt`
   - `gitlab.it205.ski.ad.key`
2. Reconfigure:
```bash
sudo gitlab-ctl reconfigure
```

---

## 3. Docker & Harbor Installation
### Install Docker
```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

### Install Harbor (Online Installer)
1. Download Harbor online installer.
2. Configure `harbor.yml`:
   ```yaml
   hostname: harbor.it205.ski.ad
   https:
     port: 443
     certificate: /path/to/harbor.it205.ski.ad.crt
     private_key: /path/to/harbor.it205.ski.ad.key
   ```
3. Run installer:
```bash
sudo ./prepare
sudo ./install.sh
```

---

## 4. Trust AD CS Root CA (Critical)
To ensure GitLab and Harbor can communicate and K8S can pull images:
```bash
sudo cp ad-cs-root-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

---
*Reference: `enterprise-containerization-cases` Issue #2*
