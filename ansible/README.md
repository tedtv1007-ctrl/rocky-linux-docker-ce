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

1. 安裝 Ansible: `sudo dnf install epel-release -y && sudo dnf install ansible -y`
2. 確保控制節點可以無密碼 SSH 登入至各個目標節點 (VM1, VM2, VM3)。

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
*執行完畢後，您可以接續 `K8S_INSTALL_GUIDE.md` 執行 `kubeadm init` 或是依照 `labs/harbor-setup.md` 完成最後的密碼設定與啟動。*