# Hyper-V 實驗室環境配置指南

本指南說明如何在 Windows 10/11 專業版或伺服器版上，利用 Hyper-V **全自動**建立與佈署適用於本專案的虛擬機環境。

### 1. 調整全域配置 (選配)
本專案所有的實驗室設定（IP、密碼、硬體規格）都集中在一個檔案，方便您快速調整：
- **路徑**: [scripts/lab-config.json](file:///D:/tedtv_github/enterprise-containerization-cases/scripts/lab-config.json)
- **可調整內容**: 預設密碼、VM 記憶體大小、IP 網段等。

---

### 2. 準備基礎作業系統映像檔

為了模擬企業環境，我們使用具有 NAT 功能的內部虛擬交換器：

```mermaid
graph TD
    Internet((Internet)) <-->|NAT Gateway| HostPC[Windows Host PC]
    
    subgraph Hyper-V 內部網路 (192.168.250.0/24)
        HostPC <-->|Gateway: 192.168.250.1| VSwitch[VSwitch: K8S-Internal]
        
        VSwitch <-->|eth0| VM1[Lab-VM1-Mgmt <br> 192.168.250.10 <br> GitLab / Harbor]
        VSwitch <-->|eth0| VM2[Lab-VM2-K8S <br> 192.168.250.20 <br> Kubernetes Node]
    end
```

## 2. 佈署流程 (IaC 快速開始)

本專案將建置分為兩個階段：**環境準備**與**服務安裝**。所有腳本均位於 `scripts/` 目錄下。

### 第一階段：環境準備 (Infrastructure Setup)

1. **以管理員身分開啟 PowerShell**。
2. **準備基礎映像檔**：下載並轉換 Rocky Linux 9 雲端映像檔 (僅需執行一次)。
   ```powershell
   .\scripts\prepare-base-vhdx.ps1
   ```
3. **建立虛擬機與網路**：建立 Switch、NAT 並產生兩台虛擬機。
   ```powershell
   .\scripts\setup-hyperv-lab.ps1
   ```
4. **啟動虛擬機**：在 Hyper-V 管理員中啟動 `Lab-VM1-Mgmt` 手動確認其已開機。

### 第二階段：服務部署 (Service Deployment)

當虛擬機開機完畢後，執行以下腳本進行自動化服務安裝：

1. **部署 VM1 服務 (GitLab & Harbor)**：
   ```powershell
   .\scripts\deploy-vm1-services.ps1
   ```
   > [!NOTE]
   > 首次執行需輸入一次密碼 `admin123` 以建立 SSH 金鑰連線，之後將全自動執行。

2. **部署 VM2 服務 (K8S 元件)**：
   ```powershell
   .\scripts\deploy-vm2-k8s.ps1
   ```

## 3. 預設登入資訊

| 服務/主機 | 存取方式 | 帳號 | 預設密碼 |
| :--- | :--- | :--- | :--- |
| **OS 登入** | SSH: `192.168.250.10` / `.20` | `sysadmin` | `admin123` |
| **GitLab** | `https://gitlab.it205.ski.ad` | `root` | *見 VM1 /etc/gitlab/initial_root_password* |
| **Harbor** | `https://harbor.it205.ski.ad` | `admin` | `Harbor12345` |

## 4. 虛擬機規格配置 (自動設定)

*   **作業系統**: Rocky Linux 9 (Generic Cloud Image)
*   **記憶體**: 4GB (啟動與最大值)，確保服務運行順暢。
*   **處理器**: 4 vCPUs
*   **Secure Boot**: 已關閉 (Cloud Image 相容性需求)。

## 5. 本機 DNS 設定 (Windows Host)

為了讓您的 Windows 瀏覽器能正確解析站台，請修改 `C:\Windows\System32\drivers\etc\hosts` 檔案，加入以下內容：
```text
192.168.250.10 gitlab.it205.ski.ad harbor.it205.ski.ad
```

## 6. 後續步驟：K8S 叢集初始化

當 `deploy-vm2-k8s.ps1` 執行完畢後，請 SSH 進入 VM2：
```bash
ssh sysadmin@192.168.250.20
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```
初始化成功後，請依循畫面提示設定 `kubeconfig` 並安裝 CNI 網路插件。

---

## ⚙️ 實驗室全局配置 (lab-config.json)

本專案所有的 IP、網段、虛擬機規格、帳號與密碼，皆統一於 [scripts/lab-config.json](file:///D:/tedtv_github/enterprise-containerization-cases/scripts/lab-config.json) 進行設定。

> [!TIP]
> **在開始佈署前，您可以先編輯此 JSON 檔**，來自定義您的環境（例如更改預設密碼 `admin123`）。

---
*最後更新日期: 2026-03-13*

