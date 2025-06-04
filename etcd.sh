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