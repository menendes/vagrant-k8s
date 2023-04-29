#!/bin/bash

set -e

ROLE=$1
HOSTNAME=$(hostname -s)

# load br_netfilter kernel module
sudo modprobe br_netfilter

# enable bridge-nf-call-iptables
sudo sysctl net.bridge.bridge-nf-call-iptables=1

# enable ip forwarding
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# Add Kubernetes GPG key and repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes and containerd
sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl containerd

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Start and enable containerd
sudo systemctl enable containerd
sudo systemctl start containerd

# Initialize the Kubernetes control plane on the master node
if [[ $ROLE == "master" ]]; then
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16

  # Configure kubectl for the current user
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Install Calico CNI
  #kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml
  kubectl taint nodes --all node-role.kubernetes.io/control-plane-
  
fi

# Join the worker nodes to the Kubernetes cluster
if [[ $ROLE == "worker"* ]]; then
  sudo kubeadm join <kubernetes-master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
fi
