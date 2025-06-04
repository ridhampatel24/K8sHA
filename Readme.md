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

    # change cgroup driver

    sudo mkdir -p /etc/containerd 
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    sudo systemctl restart containerd 
    sudo systemctl enable containerd

    # Also change the sandbox image as required by the k8s version
```

## 3. Configure Kernel Parameters

```bash
    sudo tee /etc/sysctl.d/kubernetes.conf <<EOF 
    net.bridge.bridge-nf-call-ip6tables = 1 
    net.bridge.bridge-nf-call-iptables = 1 
    net.ipv4.ip_forward = 1 
    EOF 

    sudo sysctl --system
```

## 4. Etcd Setup

### 1. Use the below script to install the etcd

```bash
    #!/bin/bash

    #sudo apt  install etcd-client
    set -euo pipefail
    ETCD_VER=v3.6.0

    # Choose download source
    GOOGLE_URL=https://storage.googleapis.com/etcd
    GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
    DOWNLOAD_URL=${GOOGLE_URL}

    # Define temp path
    TARBALL="/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz"
    EXTRACT_DIR="/tmp/etcd-download"

    # Clean up any previous artifacts
    rm -f "$TARBALL"
    rm -rf "$EXTRACT_DIR"

    # Download tarball
    echo "Downloading etcd ${ETCD_VER} from ${DOWNLOAD_URL}..."
    curl -L "${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz" -o "$TARBALL"

    # Extract to a temp dir
    mkdir -p "$EXTRACT_DIR"
    tar xzvf "$TARBALL" -C "$EXTRACT_DIR"

    # Move binaries to /usr/local/bin
    echo "Installing etcd binaries..."
    sudo cp "$EXTRACT_DIR/etcd-${ETCD_VER}-linux-amd64/etcd" /usr/local/bin/
    sudo cp "$EXTRACT_DIR/etcd-${ETCD_VER}-linux-amd64/etcdctl" /usr/local/bin/
    sudo cp "$EXTRACT_DIR/etcd-${ETCD_VER}-linux-amd64/etcdutl" /usr/local/bin/

    # Set correct permissions
    sudo chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl /usr/local/bin/etcdutl

    # Cleanup
    rm -rf "$TARBALL" "$EXTRACT_DIR"


    echo "Installed versions:"
    etcd --version
    etcdctl version
    etcdutl version
```
### 2. Generate certificates for the Etcd ssl communication


#### > Generate CA certs and Key

```bash
    sudo mkdir -p /etc/etcd/ssl
    cd /etc/etcd/ssl
    openssl genrsa -out ca.key 4096
    openssl req -x509 -new -nodes -key ca.key -subj "/CN=etcd-ca" -days 1000 -out ca.crt
```







2.4
2.5
worker
2.6
2.7
2.8
LB api server
135.235.144.80:6443
