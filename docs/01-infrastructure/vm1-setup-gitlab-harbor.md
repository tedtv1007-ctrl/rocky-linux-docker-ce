# VM1 控制節點安裝指南 (GitLab + Harbor)
# VM1 Control Plane Installation Guide (GitLab + Harbor)

本文件詳細說明如何在 VM1 (Rocky Linux 10.1) 上安裝 GitLab Omnibus 與 Harbor。
This document details the installation process for GitLab Omnibus and Harbor on VM1 (Rocky Linux 10.1).

## 1. 前置需求 (Prerequisites)
- **作業系統 (OS)**: Rocky Linux 10.1
- **網路 (Network)**: 靜態 IP (例如: `192.168.250.10`) / Static IP (e.g., 192.168.250.10)
- **完整網域名稱 (FQDNs)**: `gitlab.it205.ski.ad`, `harbor.it205.ski.ad`
- **憑證 (Certificates)**: 已信任 AD CS 根憑證 (Root CA)，並已簽發分葉憑證 (Leaf certificates)。 / AD CS Root CA trusted, Leaf certificates issued.

---

## 2. GitLab Omnibus 安裝 (GitLab Omnibus Installation)

### 安裝相依套件 (Install Dependencies)
```bash
sudo dnf install -y curl policycoreutils openssh-server perl
sudo systemctl enable sshd
sudo systemctl start sshd
```

### 安裝 GitLab (Install GitLab)
使用官方腳本新增儲存庫並安裝 GitLab EE。
```bash
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | sudo bash
sudo EXTERNAL_URL="https://gitlab.it205.ski.ad" dnf install -y gitlab-ee
```

### 設定 TLS 憑證 (Configure TLS via AD CS)
1. 將憑證檔案放置於 `/etc/gitlab/ssl/` 目錄下： / Place certificates in `/etc/gitlab/ssl/`:
   - `gitlab.it205.ski.ad.crt`
   - `gitlab.it205.ski.ad.key`
2. 重新執行設定以套用變更： / Reconfigure:
```bash
sudo gitlab-ctl reconfigure
```

---

## 3. Docker 與 Harbor 安裝 (Docker & Harbor Installation)

### 安裝 Docker (Install Docker)
```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

### 安裝 Harbor (Harbor Online Installer)
1. 下載 Harbor 線上安裝程式。 / Download Harbor online installer.
2. 編輯 `harbor.yml` 設定檔： / Configure `harbor.yml`:
   ```yaml
   hostname: harbor.it205.ski.ad
   https:
     port: 443
     certificate: /path/to/harbor.it205.ski.ad.crt
     private_key: /path/to/harbor.it205.ski.ad.key
   ```
3. 執行安裝腳本： / Run installer:
```bash
sudo ./prepare
sudo ./install.sh
```

---

## 4. 信任 AD CS 根憑證 (Trust AD CS Root CA - Critical)
為確保 GitLab、Harbor 與 Kubernetes 節點之間能安全通訊（如拉取鏡像），必須信任內部的根憑證：
To ensure GitLab and Harbor can communicate and K8S can pull images:
```bash
sudo cp ad-cs-root-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

---
*Reference: `enterprise-containerization-cases` Issue #2*
