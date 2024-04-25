#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
  echo "Script is not running as root. Attempting to elevate privileges..."
  exec sudo "$0" "$@"
  exit $?
fi
set -euo pipefail

# Function to display informational messages
info() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [INFO] $@"
}

# Function to display error messages and exit
error_exit() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [ERROR] $@" >&2
    exit 1
}

# Set hostname
set_hostname() {
    local hostname="$1"
    info "Setting hostname to: $hostname"
    hostnamectl set-hostname "$hostname" || error_exit "Failed to set hostname"
}

# Disable swap
disable_swap() {
    info "Disabling swap"
    swapoff -a || error_exit "Failed to disable swap"
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab || error_exit "Failed to update /etc/fstab"
}

# Install required packages
install_packages() {
    info "Installing required packages"
    apt-get update || error_exit "Failed to update package lists"
    apt-get install -y apt-transport-https curl wget || error_exit "Failed to install packages"
}

# Install Containerd
install_containerd() {
    info "Installing Containerd"
    local containerd_version="1.7.4"
    wget -qO- "https://github.com/containerd/containerd/releases/download/v$containerd_version/containerd-$containerd_version-linux-amd64.tar.gz" | tar -C /usr/local -xzvf - || error_exit "Failed to download and extract Containerd"
}

# Install Runc
install_runc() {
    info "Installing Runc"
    local runc_version="1.1.9"
    wget -qO /usr/local/sbin/runc "https://github.com/opencontainers/runc/releases/download/v$runc_version/runc.amd64" || error_exit "Failed to download Runc"
    chmod +x /usr/local/sbin/runc || error_exit "Failed to set execute permission on Runc"
}

# Install CNI
install_cni() {
    info "Installing CNI plugins"
    local cni_version="v1.2.0"
    mkdir -p /opt/cni/bin || error_exit "Failed to create directory /opt/cni/bin"
    wget -qO- "https://github.com/containernetworking/plugins/releases/download/$cni_version/cni-plugins-linux-amd64-$cni_version.tgz" | tar -C /opt/cni/bin -xzvf - || error_exit "Failed to download and extract CNI plugins"
}

# Install CRICTL
install_crictrl() {
    info "Installing CRICTL"
    local crictrl_version="v1.28.0"
    wget -qO /usr/local/bin/crictl "https://github.com/kubernetes-sigs/cri-tools/releases/download/$crictrl_version/crictl-$crictrl_version-linux-amd64.tar.gz" || error_exit "Failed to download CRICTL"
    chmod +x /usr/local/bin/crictl || error_exit "Failed to set execute permission on CRICTL"
}

# Configure CRICTL
configure_crictrl() {
    info "Configuring CRICTL"
    cat <<EOF >/etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF
}

# Configure kernel parameters for Kubernetes
configure_kernel() {
    info "Configuring kernel parameters for Kubernetes"
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
    sysctl --system || error_exit "Failed to apply kernel parameters"
}

# Install kubectl, kubelet and kubeadm
install_kubernetes() {
    info "Installing Kubernetes components"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - || error_exit "Failed to add Kubernetes repository key"
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list || error_exit "Failed to add Kubernetes repository"
    apt-get update || error_exit "Failed to update package lists"
    apt-get install -y kubelet kubeadm kubectl || error_exit "Failed to install Kubernetes components"
    apt-mark hold kubelet kubeadm kubectl || error_exit "Failed to hold Kubernetes packages"
}

# Print Kubeadm version
print_kubeadm_version() {
    info "Printing Kubeadm version"
    kubeadm version
}

# Main function
main() {
    set_hostname "$1"
    disable_swap
    install_packages
    install_containerd
    install_runc
    install_cni
    install_crictrl
    configure_crictrl
    configure_kernel
    install_kubernetes
    print_kubeadm_version
}

# Call main function with hostname argument
main "$1"
