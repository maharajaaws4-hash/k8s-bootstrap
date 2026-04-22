#!/bin/bash
set -e

ROLE=$1

# remove old repo if exists (IMPORTANT)
sudo rm -f /etc/apt/sources.list.d/kubernetes.list || true

if [ "$ROLE" == "master" ]; then
    echo "Setting up Kubernetes MASTER..."

    # -------------------------
    # SYSTEM SETUP
    # -------------------------
    sudo apt-get update -y
    sudo apt-get install -y docker.io curl ca-certificates apt-transport-https gpg

    sudo systemctl enable docker
    sudo systemctl start docker

    # -------------------------
    # NEW KUBERNETES REPO
    # -------------------------
    sudo mkdir -p /etc/apt/keyrings

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update -y

    # -------------------------
    # INSTALL K8S
    # -------------------------
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    # -------------------------
    # INIT CLUSTER
    # -------------------------
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16

    # -------------------------
    # KUBECONFIG
    # -------------------------
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # -------------------------
    # NETWORK (FLANNEL)
    # -------------------------
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    # -------------------------
    # JOIN COMMAND
    # -------------------------
    kubeadm token create --print-join-command > /home/ubuntu/join.sh

    echo "MASTER READY"

elif [ "$ROLE" == "worker" ]; then
    echo "Joining WORKER node..."

    JOIN_CMD=$2

    sudo apt-get update -y
    sudo apt-get install -y docker.io curl ca-certificates apt-transport-https gpg

    sudo systemctl enable docker
    sudo systemctl start docker

    # NEW REPO
    sudo mkdir -p /etc/apt/keyrings

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update -y

    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    # JOIN CLUSTER
    sudo $JOIN_CMD

    echo "WORKER JOINED"
fi
