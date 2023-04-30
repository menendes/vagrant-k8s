Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.box_check_update = false
  
  # Add a synced folder to make the k8s.env file available on the host machine
  config.vm.synced_folder ".", "/vagrant"
  
  # Define the Kubernetes master node
  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "public_network", bridge: "wlo1"
    master.vm.provider "virtualbox" do |v|
      v.memory = 2048
      v.cpus = 2
    end

    # Install Kubernetes and Calico CNI
    master.vm.provision "shell", path: "kubernetes-provision.sh", args: "master"
  end

  # Define the Kubernetes worker nodes
  (1..2).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.hostname = "worker#{i}"
      worker.vm.network "public_network", bridge: "wlo1"
      worker.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
      end
      # Install Kubernetes and Calico CNI
      worker.vm.provision "shell", path: "kubernetes-provision.sh", args: "worker#{i}"
    end
  end
end
