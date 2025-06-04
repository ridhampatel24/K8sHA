# K8s Setup HA in Azure


## Pre Flight Checks 

## 1. Disable swap memory in the all VMs

```bash

    sudo swapoff -a
    # Above cmd will disable swap memory temporary until next reboot

    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    Need to comment the swap line in /etc/fstab to disable it permanently.

    To verify it run 
    free -h
```

## 2. Install Container Runtime (containerd) and the change the Cgroup driver of the containerd to systemd


    User docker installation docs to add the repository [link](https://docs.docker.com/engine/install/ubuntu/) .

```bash
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install containerd.io

    sudo mkdir -p /etc/containerd 
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    sudo systemctl restart containerd 
    sudo systemctl enable containerd

    Also change the sandbox image as required by the k8s version

```

3. Configure Kernel Parameters

    sudo tee /etc/sysctl.d/kubernetes.conf <<EOF 
    net.bridge.bridge-nf-call-ip6tables = 1 
    net.bridge.bridge-nf-call-iptables = 1 
    net.ipv4.ip_forward = 1 
    EOF 

    sudo sysctl --system

4. Etcd Setup







2.4
2.5
worker
2.6
2.7
2.8
LB api server
135.235.144.80:6443
