# 企業內部容器化案例：從 Docker 到生產級 Kubernetes (Rocky Linux 9)

本專案提供一套完整的企業級容器化實踐路徑，協助開發與運維團隊在 Rocky Linux 9 環境下，從基礎容器技術演進至高度自動化且安全的 Kubernetes 生產級架構。

---

## 🏗 技術演進路線圖 (Roadmap)

本專案將實踐過程分為四個核心階段，建議按照順序進行：

### 0️⃣ 基礎建設 (Infrastructure)
建立穩定的實驗室環境，包括虛擬機與自動化組態管理。
- [Windows Hyper-V 自動化環境配置](./docs/01-infrastructure/hyperv-setup-guide.md)
- [虛擬機角色規劃與詳細規格](./docs/01-infrastructure/vm1-setup-gitlab-harbor.md)
- [Ansible 自動化組態管理基礎](./ansible/README.md)

### 1️⃣ 第一階段：單機容器化 (Stage 1: Docker / CI/CD Base)
建立穩定、安全的基礎容器運行環境與私有鏡像庫。
- [GitLab & Harbor 自動化佈署指南](./docs/01-infrastructure/hyperv-setup-guide.md#第二階段服務部署-service-deployment)
- [Docker CE 安裝與環境強化](./docs/02-stage-1-docker/docker-install.md)

### 2️⃣ 第二階段：叢集基礎建設 (Stage 2: K8S Base)
邁向容器編排與本地開發實驗室，建立核心網路通訊。
- [Kubernetes (Kubeadm) 叢集搭建指南](./docs/03-stage-2-kubernetes/kubeadm-install.md)

---

## ⚙️ 實驗室全局配置 (Centralized Config)

本專案所有的 IP、網段、虛擬機規格、帳號與密碼，皆統一於 [scripts/lab-config.json](file:///D:/tedtv_github/enterprise-containerization-cases/scripts/lab-config.json) 進行設定。在開始佈署前，建議您先檢查此設定檔以符合您的網路環境。

---

## 🛠 系統環境配置 (Hyper-V Lab)

| 節點角色 | 承載核心服務 | 配置 (Lab) | IP 位址 (預設) |
| :--- | :--- | :--- | :--- |
| **Mgmt Node** | GitLab, Harbor | 4 vCPU, 4GB RAM | `192.168.250.10` |
| **K8S Node** | Control Plane | 4 vCPU, 4GB RAM | `192.168.250.20` |

---

## ⚡ 快速啟動 (全自動化佈署)

本專案提供一鍵式 PowerShell 腳本，協助您在 Windows 上快速搭建實驗室：

### 1. 基礎架構建立
```powershell
# 準備映像檔 (僅需一次)
.\scripts\prepare-base-vhdx.ps1

# 建立 VM 與網路
.\scripts\setup-hyperv-lab.ps1
```

### 2. 服務自動化安裝 (ansible-driven)
```powershell
# 安裝 GitLab & Harbor (於 VM1)
.\scripts\deploy-vm1-services.ps1

# 安裝 K8S 元件 (於 VM2)
.\scripts\deploy-vm2-k8s.ps1
```

---
*Reference: enterprise-containerization-cases*

