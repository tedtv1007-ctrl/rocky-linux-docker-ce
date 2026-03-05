# 企業內部容器化案例：從 Docker 到生產級 Kubernetes (Rocky Linux 10)

本專案提供一份完整的企業級實踐指南，帶領開發與運維團隊在 Rocky Linux 10 環境下，從單機容器化逐步演進至高度可用的 Kubernetes 生產環境。

---

## 🏗 專案架構與軟體配置

本專案將基礎設施劃分為「管理節點 (Control Plane)」與「Kubernetes 叢集 (K8S Cluster)」兩大區塊。以下架構圖展示了各主機的角色與其承載的核心軟體：

```mermaid
graph TD
    subgraph 企業內部網路
        User((Dev/Ops User))
    end

    subgraph "管理節點 (VM1-Mgmt: 192.168.100.10)"
        GitLab[GitLab EE<br>原始碼管理 / CI/CD]
        Harbor[Harbor Registry<br>私有容器鏡像庫]
        Docker_Mgmt[Docker CE + Compose<br>單機容器引擎]
    end

    subgraph "Kubernetes 叢集"
        subgraph "Master Node (VM2-K8S: 192.168.100.20)"
            Kubeadm[Kubeadm / Kubelet<br>K8S 控制平面]
            Cilium_M[Cilium (eBPF)<br>網路與安全插件]
            Vault[HashiCorp Vault<br>機密資訊管理]
        end

        subgraph "Worker Node (VM3-Node2: 192.168.100.21)"
            Runner[GitLab Runner<br>K8S Executor]
            ArgoCD[Argo CD<br>GitOps 持續交付]
            Prometheus[Prometheus + Grafana<br>監控與視覺化告警]
            APISIX[APISIX Ingress<br>API 閘道器]
            Velero[Velero<br>備份與災難復原]
            Cilium_W[Cilium (eBPF)<br>網路與安全插件]
        end
    end

    User -->|Git Push / UI| GitLab
    User -->|Docker Push / Pull| Harbor
    User -->|kubectl / K8S API| Kubeadm
    User -->|HTTP/HTTPS 流量| APISIX
    
    GitLab -->|觸發 CI Pipeline| Runner
    Runner -->|構建與推送鏡像 (Kaniko)| Harbor
    ArgoCD -->|監聽配置變更| GitLab
    ArgoCD -->|自動部署應用| Kubeadm
    APISIX -->|路由至應用| Runner
```

### 核心軟體功能說明

#### 基礎建設與管理
*   **Docker CE & Compose**：輕量級容器運行時，用於在管理節點上部署基礎服務（如 Harbor）。
*   **GitLab EE**：企業級的原始碼代管平台，並內建強大的 CI/CD 引擎，作為整個研發流程的核心。
*   **Harbor**：企業級私有容器鏡像倉庫，支援基於角色的存取控制 (RBAC) 與 Trivy 漏洞掃描。

#### Kubernetes 生態系 (雲原生架構)
*   **Kubeadm / Containerd**：標準的 Kubernetes 叢集部署工具與核心的容器運行時。
*   **Cilium (eBPF)**：高效能的容器網路介面 (CNI) 插件，提供 L3-L7 的網路隔離、透明加密與 Hubble 流量視覺化。
*   **GitLab Runner (K8S Executor)**：在 K8S 內動態產生 Pod 來執行 CI/CD 任務（如使用 Kaniko 進行無特權構建），任務結束後自動回收資源。
*   **Argo CD**：GitOps 持續交付工具。它會主動監聽 GitLab 中的配置檔 (Manifests)，並自動將變更同步到 Kubernetes 叢集中。
*   **APISIX Ingress Gateway**：基於 Nginx 與 Lua 的高效能 API 閘道器，負責管理進入 K8S 叢集的外部流量 (南北向流量)。
*   **HashiCorp Vault + ESO**：Vault 用於集中且安全地存儲密碼、Token 與憑證；External Secrets Operator (ESO) 則負責將這些機密自動同步為 K8S 原生 Secret。
*   **Prometheus & Grafana**：Prometheus 負責收集叢集與應用的監控指標 (Metrics)；Grafana 提供直覺的儀表板進行視覺化與告警設定。
*   **Velero**：叢集災難復原工具，可將 K8S 資源與 Persistent Volumes (PV) 備份至外部物件儲存 (如 MinIO 或 AWS S3)。

---

## 🚀 演進路徑 (Roadmap)

本專案將容器化的導入分為三個核心階段，您可以根據需求跳轉至對應的教學：

### 1️⃣ 第一階段：單機容器化 (Single Node)
建立穩定、安全的基礎容器運行環境。
- [Docker CE 安裝與環境強化](./README_DOCKER.md)
- [Docker Compose 多服務編排範例](./DOCKER_COMPOSE_EXAMPLE.md)

### 2️⃣ 第二階段：叢集基礎建設 (Cluster Infrastructure)
邁向容器編排與本地開發實驗室。
- [Kubernetes (Kubeadm) 安裝指南](./K8S_INSTALL_GUIDE.md)
- [最小可行性 K8S 實驗室 (KinD)](./labs/mvl-k8s-lab.md)

### 3️⃣ 第三階段：生產級強化 (Production Hardening)
整合企業級工具，確保安全性與自動化。
- [企業級 GitLab 自建指南 (Rocky Linux 10)](./labs/gitlab-self-hosted.md)
- [GitLab Runner (K8S Executor) 部署指南](./labs/gitlab-runner-setup.md)
- [企業級 K8S 架構強化建議](./ENTERPRISE_K8S_HARDENING.md)
- [Cilium (eBPF) 網路安全隔離](./labs/cilium-hubble-setup.md)
- [Vault + ESO 外部密鑰同步](./labs/vault-eso-setup.md)
- [Velero 叢集備份與災難復原](./labs/velero-dr-backup.md)
- [Prometheus + Grafana 監控與告警](./labs/prometheus-grafana-stack.md)

---

## 🛠 系統環境與資源規格表

為確保各階段實驗室能順暢運行，請參考以下建議配置。所有節點皆基於 **Rocky Linux 10.1 (x86_64/arm64)**。
虛擬化平台以 **Windows Hyper-V** 為主 ([環境配置指南](./docs/hyperv-setup-guide.md))。

| 節點角色 (VM Name) | 說明 / 承載服務 | 最低配置 (Lab) | 建議配置 (Production) | IP 位址 (預設) |
| :--- | :--- | :--- | :--- | :--- |
| **Control Plane / Mgmt**<br>(Lab-VM1-Mgmt) | GitLab, Harbor (Docker 運行) | 4 vCPU, 8GB RAM<br>60GB Disk | 8 vCPU, 16GB RAM<br>100GB Disk | `192.168.100.10` |
| **K8S Master Node**<br>(Lab-VM2-K8S) | Kubeadm Master, etcd, API Server | 2 vCPU, 4GB RAM<br>40GB Disk | 4 vCPU, 8GB RAM<br>60GB Disk | `192.168.100.20` |
| **K8S Worker Node**<br>(Lab-VM3-Node2) | ArgoCD, Prometheus, APISIX, App Pods | 2 vCPU, 4GB RAM<br>40GB Disk | 4 vCPU, 16GB RAM<br>100GB Disk | `192.168.100.21` |

> 💡 **硬體總需求**：若要完整運行全套第三階段服務，實體主機建議具備 **至少 16GB RAM (推薦 32GB)** 以及 **200GB+ SSD 空間**。

---

## ⚡ 快速上手 (Windows Hyper-V)

如果您在 Windows 環境下，可以使用我們提供的自動化腳本快速建立實驗室：

1. **建立虛擬機環境** (需管理員權限 PowerShell):
   ```powershell
   .\scripts\setup-hyperv-lab.ps1
   ```
   這會自動建立 `K8S-Internal` 交換器、下載 Rocky Linux ISO 並建立兩台預設規格的虛擬機。

2. **快速複製虛擬機** (當您裝好一台乾淨的範本後):
   ```powershell
   .\scripts\fast-clone-vm.ps1 -SourceVMName "Template-VM" -NewVMName "New-Node"
   ```

3. **網路排除故障**:
   如果虛擬機無法上網，請在 Windows 管理員 PowerShell 執行：
   ```powershell
   net stop winnat; net start winnat
   New-NetNat -Name "K8S-NAT-Net" -InternalIPInterfaceAddressPrefix "192.168.100.0/24" -ErrorAction SilentlyContinue
   ```

---

## 📚 專案目錄導覽
1. [INDEX.md](./INDEX.md) - 詳細技術演進路線圖
2. [README_DOCKER.md](./README_DOCKER.md) - Docker 基礎安裝 (原 README)
3. [K8S_INSTALL_GUIDE.md](./K8S_INSTALL_GUIDE.md) - K8S 叢集安裝
4. [labs/](./labs/) - 實戰實驗室腳本與設定
5. [ansible/](./ansible/) - **(新增)** 基礎架構即代碼 (IaC) 組態管理，包含 K8S 節點與管理節點的自動化配置

---
Generated by Milk (OpenClaw)
