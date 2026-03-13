# Ansible IaC 組態管理

本目錄包含用於自動化佈署「企業內部容器化案例」實驗室環境的 Ansible Playbooks。
為了簡化實驗室搭建，我們現在提供 Windows PowerShell 封裝腳本，讓您不必在 Windows 主機安裝 Ansible 即可佈署虛擬機服務。

## 目錄結構

```text
ansible/
├── ansible.cfg              # Ansible 全局設定檔
├── certs/                   # 憑證放置區 (自動化腳本會在此產生或載入憑證)
├── inventory/
│   └── hosts.ini            # 伺服器與 IP 對應清單
└── playbooks/
    ├── vm1-master-setup.yml # [NEW] VM1 全自動佈署 (GitLab, Harbor, SSL Trust)
    ├── k8s-node-setup.yml   # 佈署 K8S 節點元件 (Containerd, Kubeadm, Kubelet)
    ├── mgmt-node-setup.yml  # (舊版) 管理節點基礎環境
    └── harbor-install.yml   # (舊版) Harbor 離線安裝包
```

## 執行流程 (推薦方式)

本專案強烈建議透過根目錄下的 `scripts/` 進行佈署。這些腳本會自動將 Ansible 腳本上傳至虛擬機並在虛擬機內部執行，免除本地環境配置的煩惱。

### 1. 佈署 VM1 (GitLab & Harbor)
執行以下指令，系統會自動在 VM1 內部執行 `vm1-master-setup.yml`：
```powershell
.\scripts\deploy-vm1-services.ps1
```

### 2. 佈署 VM2 (K8S 節點)
執行以下指令，系統會自動在 VM2 內部執行 `k8s-node-setup.yml`：
```powershell
.\scripts\deploy-vm2-k8s.ps1
```

## 進階：手動在 Linux 控制節點執行

如果您希望傳統地從 Linux 控制主機執行，請確保已設定 SSH 免密碼登入，然後：

1. **安裝 Ansible**: `sudo dnf install ansible-core -y`
2. **執行完成版佈署**:
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/vm1-master-setup.yml
   ```

---
*Reference: enterprise-containerization-cases automated via Ansible-on-VM*