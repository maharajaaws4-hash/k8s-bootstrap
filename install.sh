#!/bin/bash
set -e

ROLE=$1

# remove old repo if exists
sudo rm -f /etc/apt/sources.list.d/kubernetes.list || true

# -------------------------
# COMMON SETUP (MASTER + WORKER)
# -------------------------
sudo apt-get update -y
sudo apt-get install -y docker.io curl ca-certificates apt-transport-https gpg

sudo systemctl enable docker
sudo systemctl start docker

# Disable swap (IMPORTANT for kubeadm)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl settings
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# -------------------------
# KUBERNETES REPO (FIXED GPG ISSUE)
# -------------------------
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
gpg --dearmor --batch --yes | \
sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y

sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# -------------------------
# MASTER NODE
# -------------------------
if [ "$ROLE" == "master" ]; then
    echo "Setting up Kubernetes MASTER..."

    sudo kubeadm init --pod-network-cidr=10.244.0.0/16

    mkdir -p $HOME/.kube
    sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Flannel network
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

    # Save join command
    kubeadm token create --print-join-command > /home/ubuntu/join.sh

    echo "MASTER READY"

# -------------------------
# WORKER NODE
# -------------------------
elif [ "$ROLE" == "worker" ]; then
    echo "Joining WORKER node..."

    JOIN_CMD=$2

    sudo $JOIN_CMD

    echo "WORKER JOINED"
fi
