#!/bin/bash
# scripts/install-cilium.sh
# Purpose: Automate Cilium CLI and Network Plugin installation
# Author: Gemini CLI

set -e

echo "=========================================================="
echo " Starting Cilium (eBPF) Installation..."
echo "=========================================================="

# 1. Download Cilium CLI
echo "Step 1: Downloading Cilium CLI..."
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

# 2. Check for Kubeconfig
if [ ! -f "$HOME/.kube/config" ]; then
    echo "ERROR: Kubeconfig not found at $HOME/.kube/config."
    echo "Please ensure you have run 'kubeadm init' and set up your config first."
    exit 1
fi

# 3. Install Cilium Plugin
echo "Step 2: Deploying Cilium CNI to the cluster..."
# Untaint node for single-node setup (otherwise pods stay Pending)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

cilium install --version 1.16.1

# 4. Wait for Ready
echo "Step 3: Waiting for Cilium components to be ready..."
cilium status --wait

echo "=========================================================="
echo " Cilium Installation Complete! Your nodes should be Ready."
echo "=========================================================="
kubectl get nodes
