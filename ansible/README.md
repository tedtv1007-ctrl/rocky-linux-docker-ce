# Ansible IaC 組態管理

本目錄包含用於自動化佈署「企業內部容器化案例」實驗室環境的 Ansible Playbooks。
透過這些 Playbooks，您可以快速且具備冪等性地建立 K8S 節點與管理節點。

## 目錄結構

```text
ansible/
├── ansible.cfg              # Ansible 全局設定檔
├── inventory/
│   └── hosts.ini            # 伺服器與 IP 對應清單
└── playbooks/
    ├── k8s-node-setup.yml   # 佈署 K8S 基礎環境 (Docker, Containerd, Kubeadm)
    ├── mgmt-node-setup.yml  # 佈署管理節點基礎環境 (Docker, Compose)
    └── harbor-install.yml   # 下載並配置 Harbor 離線安裝包
```

## 執行需求
在您的控制節點 (例如您的 Windows 透過 WSL，或任一 Linux 虛擬機) 執行以下操作：

1. **安裝 Ansible**: `sudo dnf install epel-release -y && sudo dnf install ansible -y`
2. **設定無密碼 SSH 登入**: 
   為了讓 Ansible 能夠自動化操作目標節點，您需要從「控制節點」產生 SSH 金鑰並發送到「目標節點 (VM1, VM2, VM3)」：
   
   - **產生 SSH 金鑰** (若已有則跳過):
     ```bash
     ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
     ```
   - **將金鑰複製到目標節點** (請替換為實際 IP):
     ```bash
    ssh-copy-id root@192.168.250.10
    ssh-copy-id root@192.168.250.20
    ssh-copy-id root@192.168.250.21
     ```
   - **測試連線**: 確保不需要密碼即可登入。
     ```bash
    ssh root@192.168.250.10 "hostname"
     ```

## 使用方式

請在 `ansible/` 目錄下執行以下指令：

### 1. 準備管理節點 (VM1 - GitLab & Harbor)
安裝 Docker、Docker Compose 等基礎套件：
```bash
ansible-playbook playbooks/mgmt-node-setup.yml
```

準備 Harbor 安裝環境：
```bash
ansible-playbook playbooks/harbor-install.yml
```

### 2. 準備 K8S 節點 (VM2, VM3)
自動關閉 Swap、設定網路模組並安裝 Kubeadm、Kubelet 與 Containerd：
```bash
ansible-playbook playbooks/k8s-node-setup.yml
```

---
*執行完畢後，您可以接續 [Kubeadm 叢集搭建指南](../docs/03-stage-2-kubernetes/kubeadm-install.md) 執行 `kubeadm init` 或是依照 [Harbor 部署指南](../docs/02-stage-1-docker/harbor-setup.md) 完成最後的密碼設定與啟動。*