#!/bin/bash

set -e

echo "🔄 Updating system..."
sudo apt update -y
sudo apt upgrade -y

echo "🌐 Checking internet connectivity..."
ping -c 2 8.8.8.8 > /dev/null || { echo "No internet! Exiting."; exit 1; }

echo "📦 Installing required packages..."
sudo apt install -y apt-transport-https ca-certificates curl gpg

echo "🐳 Installing containerd..."
sudo apt install -y containerd

echo "⚙️ Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "🔧 Enabling kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "🧠 Setting sysctl params..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "🚀 Adding Kubernetes repo..."
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update -y

echo "📥 Installing kubeadm, kubelet, kubectl..."
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "📦 Pre-pulling Kubernetes images..."
sudo kubeadm config images pull

echo "✅ All components installed successfully!"
echo "Now you can run: sudo kubeadm init"
