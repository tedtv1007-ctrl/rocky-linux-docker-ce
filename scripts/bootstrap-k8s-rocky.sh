#!/bin/bash
# enterprise-containerization-cases/scripts/bootstrap-k8s-rocky.sh
# Purpose: Automate K8S node preparation and kubeadm init for Rocky Linux 10.1
# Author: Milk (AI Assistant)

set -e

echo "Starting K8S Bootstrap for Rocky Linux 10.1..."

# 1. Environment Check
echo "[0/6] Checking Environment..."
OS_VERSION=$(grep "VERSION_ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
if [[ "$OS_VERSION" != "10.1" ]]; then
    echo "Warning: This script is optimized for Rocky Linux 10.1. Detected version: $OS_VERSION"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (or with sudo)"
   exit 1
fi

# 2. Disable Swap (Required for K8S)
echo "[1/6] Disabling Swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 3. Kernel Modules & Sysctl
echo "[2/6] Configuring Kernel Modules & Network..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 3. Install Containerd (CRI)
echo "[3/6] Installing Containerd..."
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 4. Install K8S Components
echo "[4/6] Installing kubeadm, kubelet, kubectl & network tools..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

# Install K8S tools + conntrack (Mandatory for K8S networking)
sudo dnf install -y kubelet kubeadm kubectl conntrack-tools --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# Fix local hostname resolution for kubeadm pre-flight checks
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts

# 5. Firewall (Permissive for Lab, but documented)
echo "[5/6] Adjusting Firewall..."
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 6. Kubeadm Init (Instructional)
echo "[6/6] Bootstrap Complete!"
echo "To initialize the cluster, run:"
echo "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=\"$(hostname -f)\""
echo ""
echo "After init, remember to:"
echo "mkdir -p \$HOME/.kube"
echo "sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
