#!/bin/bash

ROLE=$1

if [ "$ROLE" == "master" ]; then
    echo "Setting up Kubernetes MASTER..."

    sudo apt update -y

    sudo apt install -y docker.io apt-transport-https curl

    sudo systemctl enable docker
    sudo systemctl start docker

    sudo apt install -y kubeadm kubelet kubectl

    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt update -y
    sudo apt install -y kubeadm kubelet kubectl

    sudo kubeadm init --pod-network-cidr=10.244.0.0/16

    # setup kube config
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # generate join command
    kubeadm token create --print-join-command > /home/ubuntu/join.sh

    echo "MASTER READY"

elif [ "$ROLE" == "worker" ]; then
    echo "Joining WORKER node..."

    JOIN_CMD=$2

    sudo apt update -y
    sudo apt install -y docker.io apt-transport-https curl

    sudo systemctl enable docker
    sudo systemctl start docker

    sudo apt install -y kubeadm kubelet kubectl

    eval $JOIN_CMD

    echo "WORKER JOINED"
fi
