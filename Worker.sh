#!/bin/bash
set -euo pipefail

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Function to display messages
function log_info {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - INFO - $1"
}

# Function to display error messages and exit
function log_error_and_exit {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ERROR - $1" >&2
    exit 1
}

# Set hostname
log_info "Setting hostname"
hostnamectl set-hostname "$1" || log_error_and_exit "Failed to set hostname"

# Disable swap
log_info "Disabling swap"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Install Containerd
log_info "Installing Containerd"
containerd_version="1.7.4"
wget -qO- "https://github.com/containerd/containerd/releases/download/v$containerd_version/containerd-$containerd_version-linux-amd64.tar.gz" | tar -C /usr/local -xzvf - || log_error_and_exit "Failed to install Containerd"
wget -qO /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service || log_error_and_exit "Failed to download Containerd service file"
systemctl daemon-reload
systemctl enable --now containerd || log_error_and_exit "Failed to enable Containerd service"

# Install Runc
log_info "Installing Runc"
runc_version="1.1.9"
wget -qO /usr/local/sbin/runc "https://github.com/opencontainers/runc/releases/download/v$runc_version/runc.amd64" || log_error_and_exit "Failed to install Runc"
chmod +x /usr/local/sbin/runc

# Install CNI
log_info "Installing CNI"
cni_version="v1.2.0"
wget -qO- "https://github.com/containernetworking/plugins/releases/download/$cni_version/cni-plugins-linux-amd64-$cni_version.tgz" | tar -C /opt/cni/bin -xzvf - || log_error_and_exit "Failed to install CNI"

# Install CRICTL
log_info "Installing CRICTL"
crictl_version="v1.28.0"
wget -qO /usr/local/bin/crictl "https://github.com/kubernetes-sigs/cri-tools/releases/download/$crictl_version/crictl-$crictl_version-linux-amd64.tar.gz" || log_error_and_exit "Failed to install CRICTL"
chmod +x /usr/local/bin/crictl

# Configure CRICTL
log_info "Configuring CRICTL"
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# Configure kernel parameters for Kubernetes
log_info "Configuring Kernel"
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Install kubectl, kubelet and kubeadm
log_info "Installing Kubectl, Kubelet and Kubeadm"
apt-get update || log_error_and_exit "Failed to update package lists"
apt-get install -y apt-transport-https curl || log_error_and_exit "Failed to install prerequisites"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - || log_error_and_exit "Failed to add GPG key"
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt-get update || log_error_and_exit "Failed to update package lists after adding Kubernetes repository"
apt-get install -y kubelet kubeadm kubectl || log_error_and_exit "Failed to install Kubernetes components"
apt-mark hold kubelet kubeadm kubectl

# Print Kubeadm version
log_info "Printing Kubeadm version"
kubeadm version
