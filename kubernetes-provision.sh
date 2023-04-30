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
  # Get the IP address of the master node
  MASTER_IP=$(hostname -I | awk '{print $2}') 
  
  #initialize cluster--control-plane=
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$MASTER_IP
  
  #get join command
  JOIN_CMD=$(kubeadm token create --print-join-command)
  
  # Write the required values to a file
  echo "export KUBERNETES_MASTER_IP=$MASTER_IP" > /vagrant/k8s.env
  echo "export KUBERNETES_JOIN_COMMAND='$JOIN_CMD'" >> /vagrant/k8s.env

  # Configure kubectl for the current user
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Install Calico CNI
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml
  kubectl taint nodes --all node-role.kubernetes.io/control-plane-
fi

# Join the worker nodes to the Kubernetes cluster
if [[ $ROLE == "worker"* ]]; then
  # Get Kubernetes master IP and token from environment variables
  source /vagrant/k8s.env
  export KUBERNETES_NODE_NAME=#{worker.vm.hostname}
  sudo $KUBERNETES_JOIN_COMMAND
fi
