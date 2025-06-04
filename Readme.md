# K8s Setup HA


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
### 2. Generate certificates for the Etcd SSL communication


#### > Generate CA certs and Key

```bash
    sudo mkdir -p /etc/etcd/ssl
    cd /etc/etcd/ssl
    openssl genrsa -out ca.key 4096
    openssl req -x509 -new -nodes -key ca.key -subj "/CN=etcd-ca" -days 1000 -out ca.crt
```
#### > Generate etcd server certs and key

```bash
    openssl genrsa -out etcd.key 4096

    ## openssl.cnf file is required to generate the etcd server certs
    ## openssl.cnf file content is as follows
```
##### openssl.cnf

```bash
    [ req ]
    distinguished_name = req_distinguished_name
    req_extensions = v3_req
    prompt = no

    [ req_distinguished_name ]
    CN = etcd-server

    [ v3_req ]
    keyUsage = critical, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names

    [ alt_names ]
    DNS.1 = localhost
    IP.1 = 127.0.0.1
    # Replace with your VM IP
    IP.2 = 192.168.1.4
```
```bash

    ## Generate the etcd server certificate signing request (CSR)
    openssl req -new -key etcd.key -out etcd.csr -config openssl.cnf

    ## Generate the etcd server certificate using the CA certs and key
    openssl x509 -req -in etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd.crt -days 1000 -extensions v3_req -extfile openssl.cnf
```
#### > Create client certs and key

```bash
    openssl genrsa -out client.key 2048

    ## etcd-client-openssl.conf file is required to generate the client certs
    ## etcd-client-openssl.conf file content is as follows
```
##### etcd-client-openssl.conf
```bash
    [ req ]
    distinguished_name = req_distinguished_name
    req_extensions = v3_req
    prompt = no

    [ req_distinguished_name ]
    CN = etcd-client

    [ v3_req ]
    keyUsage = critical, digitalSignature, keyEncipherment
    extendedKeyUsage = clientAuth
```
#####

```bash
    ## Generate the client certificate signing request (CSR)
    openssl req -new -key client.key -out etcd-client.csr -config etcd-client-openssl.conf

    ## Generate the client certificate using the CA certs and key
    openssl x509 -req -in etcd-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -extensions v3_req -extfile etcd-client-openssl.conf
```
#### > Verify the generated certificates

```bash
    openssl x509 -in etcd.crt -text -noout
    openssl x509 -in client.crt -text -noout
    openssl x509 -in ca.crt -text -noout
```
#### > Copy the generated certificates to the master nodes


### 3. Run ETCD as a systemd service

```bash

    sudo tee /etc/systemd/system/etcd.service <<EOF
    [Unit]
    Description=etcd key-value store
    Documentation=https://etcd.io/docs/
    After=network.target

    [Service]
    Type=notify
    ExecStart=/usr/local/bin/etcd \
    --name etcd-server \
    --data-dir /var/lib/etcd \
    --listen-client-urls https://192.168.1.4:2379,https://127.0.0.1:2379 \
    --advertise-client-urls https://192.168.1.4:2379 \
    --cert-file /etc/etcd/ssl/etcd.crt \
    --key-file /etc/etcd/ssl/etcd.key \
    --trusted-ca-file /etc/etcd/ssl/ca.crt \
    --client-cert-auth=true
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=40000

    [Install]
    WantedBy=multi-user.target
    EOF
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd
```











