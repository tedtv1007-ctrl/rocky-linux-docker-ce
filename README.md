# 企業內部容器化案例：從 Docker 到生產級 Kubernetes (Rocky Linux 9/10)

本專案提供一套完整的企業級容器化實踐路徑，協助開發與運維團隊在 Windows 環境下（支援 Pro/Home 版），利用 Hyper-V 與 Ansible 自動化，從基礎容器技術演進至高度自動化且安全的 Kubernetes 生產級架構。

---

## 🏗 技術演進路線圖 (Roadmap)

本專案將實踐過程分為四個核心階段，建議按照順序進行：

### 0️⃣ 基礎建設 (Infrastructure)
建立穩定的實驗室環境，包括虛擬機與自動化組態管理。
- [Windows 11 Home 版解鎖 Hyper-V 腳本](./scripts/enable-hyperv-home.ps1)
- [Windows Hyper-V 自動化環境配置 (IaC)](./docs/01-infrastructure/hyperv-setup-guide.md)
- [Ansible 自動化組態管理基礎 (Hardened)](./ansible/README.md)

### 1️⃣ 第一階段：單機容器化 (Stage 1: Docker / CI/CD Base)
建立穩定、安全的基礎容器運行環境與私有鏡像庫。
- [GitLab & Harbor 自動化佈署指南](./docs/01-infrastructure/hyperv-setup-guide.md#第二階段服務部署-service-deployment)
- [Docker CE 安裝與環境強化](./docs/02-stage-1-docker/docker-install.md)

### 2️⃣ 第二階段：叢集基礎建設 (Stage 2: K8S Base)
邁向容器編排與本地開發實驗室，建立核心網路通訊。
- [Kubernetes (Kubeadm) 叢集搭建指南](./docs/03-stage-2-kubernetes/kubeadm-install.md)
- **核心組件**：containerd (CRI), Cilium (eBPF CNI), kubeadm v1.31+

### 3️⃣ 第三階段：企業級強化 (Stage 3: Enterprise Stack)
實踐企業級安全、觀測性與自動化運維。
- **流量治理**：APISIX API Gateway (WAF / Auth)
- **自動化運維**：ArgoCD (GitOps), MetalLB (L4 LB)
- **安全性 (Hardening)**：Falco (Runtime Security), Trivy (CVE Scan)
- **機密管理**：Vault + External Secrets Operator (ESO)
- **災難復原**：Velero (DR/Backup)

---

## ⚙️ 實驗室全局配置 (Centralized Config)

本專案所有的 IP、網段、虛擬機規格、帳號與密碼，皆統一於 [scripts/lab-config.json](./scripts/lab-config.json) 進行設定。在開始佈署前，建議您先檢查此設定檔以符合您的網路環境。

---

## 🛠 系統環境配置 (Hyper-V Lab)

| 節點角色 | 承載核心服務 | 配置 (Lab) | IP 位址 (預設) |
| :--- | :--- | :--- | :--- |
| **Mgmt Node** | GitLab, Harbor | 4 vCPU, 4GB RAM | `192.168.250.10` |
| **K8S Node** | Control Plane + Node | 4 vCPU, 4GB RAM (Min 3GB) | `192.168.250.20` |

---

## ⚡ 快速啟動 (全自動化佈署)

本專案提供一鍵式 PowerShell 腳本，協助您在 Windows 上快速搭建實驗室：

### 1. 基礎架構建立
```powershell
# [Home 版專屬] 啟用 Hyper-V (需要管理員權限並重啟)
.\scripts\enable-hyperv-home.ps1

# 準備映像檔 (僅需一次)
.\scripts\prepare-base-vhdx.ps1

# 建立 VM 與網路
.\scripts\setup-hyperv-lab.ps1
```

### 2. 服務自動化安裝
```powershell
# 安裝 GitLab & Harbor (於 VM1)
.\scripts\deploy-vm1-services.ps1

# 安裝 K8S 元件 (於 VM2)
.\scripts\deploy-vm2-k8s.ps1
```

### 3. K8S 叢集初始化 (於 VM2)
```bash
# 1. 執行 Kubeadm 初始化
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 2. 設定使用者權限 (依畫面提示)
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 3. 部署 Cilium 網路 (一鍵腳本)
./install-cilium.sh
```

---

## 🛡️ 企業級強化亮點
- **安全掃描**：整合 Trivy 於 GitLab CI 中生成 SBOM 並阻斷高危漏洞。
- **核心效能**：自動啟用 **TCP BBR** 與系統級優化。
- **.NET 9 支援**：提供多階段構建 (Multi-stage) 與 Ubuntu Chiseled 最小化安全鏡像。
- **eBPF 網路**：使用 Cilium 提供 Identity-based 安全與可觀測性。

---
*Reference: enterprise-containerization-cases*
