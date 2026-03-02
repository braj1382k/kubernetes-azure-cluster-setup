#!/bin/bash
# Kubernetes Master Node Setup Script
# Run as: sudo bash setup-master.sh

# --- Step 1: Update system ---
echo "Updating system packages..."
apt update && apt upgrade -y

# --- Step 2: Disable swap ---
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# --- Step 3: Enable kernel modules ---
echo "Loading kernel modules..."
modprobe overlay
modprobe br_netfilter
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# --- Step 4: Networking settings ---
echo "Applying network sysctl settings..."
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# --- Step 5: Install containerd runtime ---
echo "Installing containerd..."
apt install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- Step 6: Add Kubernetes repo and install kubeadm, kubelet, kubectl ---
echo "Installing Kubernetes components..."
apt install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- Step 7: Initialize master node ---
echo "Initializing Kubernetes master node..."
kubeadm init --pod-network-cidr=10.244.0.0/16

# --- Step 8: Configure kubectl for non-root user ---
echo "Setting up kubectl for the user..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# --- Step 9: Install Flannel network plugin ---
echo "Installing Flannel network..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "Master node setup complete! Check node status with 'kubectl get nodes'"