#!/bin/bash

# ===============================================
# Kubernetes Worker Node Setup Script
# ===============================================
# This script sets up a Kubernetes worker node (slave node)
# and joins it to an existing cluster. It includes instructions
# and comments explaining each step.

# 1️⃣ Update the system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2️⃣ Disable swap (Kubernetes requirement)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3️⃣ Enable required kernel modules for Kubernetes networking
echo "Loading kernel modules..."
sudo modprobe overlay
sudo modprobe br_netfilter

# Persist kernel module settings
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 4️⃣ Configure sysctl settings for Kubernetes networking
echo "Applying sysctl settings..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 5️⃣ Install containerd (container runtime)
echo "Installing containerd..."
sudo apt install -y containerd

# Configure containerd with default settings
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 6️⃣ Install Kubernetes tools (kubeadm, kubelet, kubectl)
echo "Installing Kubernetes tools..."
sudo apt install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
| sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 7️⃣ Join the Kubernetes cluster
# Replace the variables below with values from your master node
MASTER_IP="172.16.0.4"   # Master node private IP
TOKEN="pp3rwm.oubdtwo7j0j0wa54"  # kubeadm join token
HASH="sha256:43bf56a2379970e2a581ee51420fe2a8c1bd70e8c4a25677eac3092814638ff2"  # Discovery token CA hash

echo "Joining the Kubernetes cluster..."
sudo kubeadm join $MASTER_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash $HASH

# 8️⃣ Instructions for verification
echo ""
echo "✅ Worker node setup completed."
echo "Run the following on your master node to verify:"
echo "kubectl get nodes"
echo "You should see this worker node listed with STATUS=Ready"