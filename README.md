# Kubernetes Cluster on AWS using Terraform & Ansible

This project automates the deployment of a **Kubernetes cluster on AWS** using **Terraform** for infrastructure provisioning and **Ansible** for cluster configuration.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Project Structure](#project-structure)
5. [Installation & Setup](#installation--setup)
6. [Configuration](#configuration)
7. [Deployment Steps](#deployment-steps)
8. [Accessing Your Cluster](#accessing-your-cluster)
9. [Cluster Verification](#cluster-verification)
10. [Cleanup](#cleanup)
11. [Troubleshooting](#troubleshooting)
12. [Security Recommendations](#security-recommendations)

---

## Overview

This project creates a production-ready Kubernetes cluster on AWS with:
- **1 Master Node** - Controls the cluster and manages workloads
- **2 Worker Nodes** - Run your containerized applications
- **Container Runtime** - containerd (industry standard)
- **Network Plugin** - Weave for pod-to-pod communication
- **Infrastructure as Code** - Terraform for reproducible deployments

### Technologies Used
- **Terraform** - Infrastructure provisioning
- **Ansible** - Configuration management
- **Kubernetes (kubeadm)** - Cluster orchestration
- **AWS EC2** - Compute resources
- **AWS Security Groups** - Network security

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS VPC (Default)                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │   Master Node    │         │   Worker Node 1  │    │
│  │  (t2.medium)     │◄──────► │   (t2.micro)     │    │
│  │                  │         │                  │    │
│  │ - API Server     │         │ - kubelet        │    │
│  │ - etcd           │         │ - containerd     │    │
│  │ - Controller     │         │ - kube-proxy     │    │
│  │ - Scheduler      │         │                  │    │
│  └──────────────────┘         └──────────────────┘    │
│           │                                             │
│           └──────────────┬──────────────────┐          │
│                          │                  │          │
│                  ┌──────────────────┐       │          │
│                  │   Worker Node 2  │       │          │
│                  │   (t2.micro)     │◄──────          │
│                  │                  │                  │
│                  │ - kubelet        │                  │
│                  │ - containerd     │                  │
│                  │ - kube-proxy     │                  │
│                  └──────────────────┘                  │
│                                                         │
│  All connected via Weave Network (pod networking)     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before you start, ensure you have the following installed on your local machine:

### Required Software
1. **Terraform** (v1.0+)
   ```bash
   # Download from: https://www.terraform.io/downloads
   terraform --version
   ```

2. **Ansible** (v2.9+)
   ```bash
   pip install ansible
   ansible --version
   ```

3. **AWS CLI** (v2+)
   ```bash
   # Download from: https://aws.amazon.com/cli/
   aws --version
   ```

4. **kubectl** (optional, for managing the cluster)
   ```bash
   # Download from: https://kubernetes.io/docs/tasks/tools/
   kubectl version --client
   ```

5. **Git** (for cloning the repository)
   ```bash
   git --version
   ```

### AWS Credentials
- AWS account with **EC2, VPC, and Security Group** permissions
- Configure AWS credentials:
  ```bash
  aws configure
  # Enter: Access Key ID, Secret Access Key, Region, Output Format
  ```

### SSH Key Setup
- An SSH keypair for accessing EC2 instances
- The private key will be created by Terraform automatically

---

## Project Structure

```
terraform-ansible-k8s/
├── README.md                 # This file
├── .gitignore               # Git ignore patterns
│
├── # Terraform Configuration Files
├── provider.tf              # AWS provider setup
├── variables.tf             # Input variables
├── main.tf                  # EC2 instances (Master & Worker nodes)
├── sg.tf                    # Security groups
├── keypair.tf               # SSH keypair
├── outputs.tf               # Terraform outputs
│
├── # Kubernetes Setup Scripts
├── Master.sh                # Master node initialization
├── Worker.sh                # Worker node initialization
├── join-command.sh          # Generated file (worker join token)
│
├── # Ansible Configuration
├── ansible.cfg              # Ansible settings
├── playbook.yml             # Ansible playbook
│
└── # SSH Keys (Generated during deployment)
    └── k8s                  # Private key (DO NOT COMMIT)
    └── k8s.pub              # Public key
```

---

## Installation & Setup

### Step 1: Clone the Repository
```bash
git clone https://github.com/shubham-saini18/terraform-ansible-k8s.git
cd terraform-ansible-k8s
```

### Step 2: Initialize Terraform
Terraform needs to download the AWS provider plugin:
```bash
terraform init
```

**Expected output:**
```
Terraform has been successfully configured!
```

### Step 3: Review the Terraform Plan
See what resources will be created:
```bash
terraform plan
```

**You should see:**
- 1 AWS Security Group for Master
- 1 AWS Security Group for Worker
- 1 AWS Key Pair
- 1 Master EC2 instance (t2.medium)
- 2 Worker EC2 instances (t2.micro)

---

## Configuration

### Customize Deployment Variables

Edit `variables.tf` to change default settings:

```hcl
variable "region" {
  default = "ap-south-1"  # Change to your AWS region
}

variable "instance_type" {
  default = {
    master = "t2.medium"   # Master node instance type
    worker = "t2.micro"    # Worker node instance type
  }
}

variable "worker_instance_count" {
  default = 2             # Number of worker nodes
}

variable "ami" {
  default = {
    master = "ami-007020fd9c84e18c7"  # Ubuntu 20.04 LTS in ap-south-1
    worker = "ami-007020fd9c84e18c7"
  }
}
```

**Note:** If using a different AWS region, find the correct Ubuntu AMI ID:
```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" \
  --region us-east-1
```

### Security Group Configuration

Edit `sg.tf` to restrict access:

**Current:** SSH and Kubernetes ports are open to `0.0.0.0/0` (anywhere)

**Recommended:** Restrict to your IP:
```hcl
cidr_blocks = ["YOUR_IP/32"]  # Replace YOUR_IP with your public IP
```

Find your IP:
```bash
curl https://checkip.amazonaws.com
```

---

## Deployment Steps

### Step 1: Create AWS Resources
```bash
terraform apply
```

**When prompted:**
```
Do you want to perform these actions?
  Terraform will perform the actions described above.

Type 'yes' to confirm
```

Type `yes` and press Enter.

**This will take ~10-15 minutes**. Terraform will:
1. Create security groups
2. Create EC2 instances
3. Run setup scripts on Master and Worker nodes
4. Initialize the Kubernetes cluster

### Step 2: Monitor the Deployment

While Terraform is running, you can check progress in the AWS console:
- EC2 Dashboard → Instances → Watch status change from "pending" to "running"

### Step 3: Verify Deployment Success

After `terraform apply` completes, you should see:

```
Outputs:
master_ip = "XX.XX.XX.XX"
worker_ips = [
  "YY.YY.YY.YY",
  "ZZ.ZZ.ZZ.ZZ"
]
```

---

## Accessing Your Cluster

### Step 1: SSH into Master Node
```bash
ssh -i k8s ubuntu@<MASTER_IP>
```

Replace `<MASTER_IP>` with the IP from Terraform output.

**Example:**
```bash
ssh -i k8s ubuntu@13.232.45.67
```

### Step 2: Check Cluster Status
```bash
# From Master node
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES           AGE    VERSION
# k8s-master     Ready    control-plane   5m     v1.30.0
# k8s-worker-0   Ready    <none>          3m     v1.30.0
# k8s-worker-1   Ready    <none>          3m     v1.30.0
```

### Step 3: Check Pod Status
```bash
# View system pods
kubectl get pods --all-namespaces

# View running containers
kubectl get pods -A -o wide
```

### Step 4: Access from Local Machine

Copy the kubeconfig file to your local machine:

```bash
# From local machine
scp -i k8s ubuntu@<MASTER_IP>:/home/ubuntu/.kube/config ./kubeconfig

# Set kubectl to use this config
export KUBECONFIG=$(pwd)/kubeconfig

# Verify access
kubectl get nodes
```

---

## Cluster Verification

### 1. Check All Nodes are Ready
```bash
kubectl get nodes
```
All nodes should show `STATUS: Ready`

### 2. Check System Pods
```bash
kubectl get pods -n kube-system
```
Expected pods:
- coredns (DNS)
- weave-net (Networking)
- kube-proxy (Service networking)

### 3. Check Pod Network
```bash
# Get pod IPs
kubectl get pods -A -o wide

# Test connectivity between pods
kubectl run test-pod --image=busybox --rm -it -- sh
# Inside pod: ping <another_pod_ip>
```

### 4. Verify Kubernetes Version
```bash
kubectl version
```

### 5. Check Cluster Health
```bash
# Get cluster status
kubectl cluster-info

# Check component status
kubectl get componentstatuses
```

---

## Deploying Your First Application

### Deploy a Simple Nginx Web Server

```bash
# Create a deployment
kubectl create deployment nginx --image=nginx:latest --replicas=2

# Expose as a service
kubectl expose deployment nginx --type=NodePort --port=80

# Check service
kubectl get svc
```

Visit the application:
```
http://<WORKER_IP>:<NodePort>
```

### Deploy from YAML File

Create `app.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  selector:
    app: my-app
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Deploy:
```bash
kubectl apply -f app.yaml
```

---

## Cleanup

### Destroy All AWS Resources

```bash
terraform destroy
```

**When prompted:**
```
Do you really want to destroy all resources?
Type 'yes' to confirm
```

Type `yes` and press Enter.

**This will delete:**
- All EC2 instances
- All Security Groups
- SSH Key Pair
- Network interfaces

---

## Troubleshooting

### Issue 1: Terraform Init Fails
**Error:** `Error: error configuring Terraform AWS Provider`

**Solution:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Reconfigure AWS CLI
aws configure
```

### Issue 2: SSH Connection Refused
**Error:** `Connection refused` when trying to SSH

**Solution:**
- Wait 2-3 minutes after `terraform apply` completes (instances need time to boot)
- Check security group allows port 22 from your IP
- Verify key file permissions: `chmod 600 k8s`

### Issue 3: Nodes Not Ready
**Error:** `kubectl get nodes` shows `NotReady` status

**Solution:**
```bash
# SSH into node and check services
ssh -i k8s ubuntu@<NODE_IP>

# Check containerd status
sudo systemctl status containerd

# Check kubelet logs
sudo journalctl -u kubelet -n 50

# Restart kubelet if needed
sudo systemctl restart kubelet
```

### Issue 4: Pods Not Running
**Error:** Pods stuck in `Pending` or `CrashLoopBackOff`

**Solution:**
```bash
# Check pod events
kubectl describe pod <POD_NAME> -n <NAMESPACE>

# Check node resources
kubectl top nodes
kubectl top pods -A

# Check logs
kubectl logs <POD_NAME> -n <NAMESPACE>
```

### Issue 5: Worker Nodes Won't Join
**Error:** Worker nodes show `NotReady` or fail to connect

**Solution:**
```bash
# SSH into worker and check join process
ssh -i k8s ubuntu@<WORKER_IP>

# Check if join-command ran successfully
sudo cat /var/log/syslog | grep -i join

# Manually rejoin (if needed)
sudo sh ~/join-command.sh
```

### Issue 6: Weave Network Issues
**Error:** Pods can't communicate between nodes

**Solution:**
```bash
# Check Weave pod status
kubectl get pods -n kube-system | grep weave

# Check Weave logs
kubectl logs -n kube-system <WEAVE_POD_NAME>

# Restart Weave
kubectl rollout restart daemonset weave-net -n kube-system
```

---

## Security Recommendations

⚠️ **This cluster is currently open to the internet. For production use:**

### 1. Restrict Security Groups
Edit `sg.tf` to only allow:
- SSH from your IP/bastion host
- Kubernetes API from authorized networks
- Node ports only from your infrastructure

Example:
```hcl
cidr_blocks = ["203.0.113.0/24"]  # Your organization's IP range
```

### 2. Use Private Subnets
- Deploy nodes in private subnets
- Use a bastion host for SSH access
- Use VPN for cluster access

### 3. Enable RBAC
```bash
# Verify RBAC is enabled
kubectl api-resources

# Create restrictive policies
kubectl create serviceaccount app-user
kubectl create role app-role --verb=get,list --resource=pods
kubectl create rolebinding app-bind --role=app-role --serviceaccount=default:app-user
```

### 4. Encrypt Secrets
```bash
# Enable encryption for etcd
# Edit /etc/kubernetes/manifests/kube-apiserver.yaml
# Add encryption configuration
```

### 5. Regular Updates
```bash
# Check for Kubernetes updates
kubeadm version
kubeadm upgrade plan
```

### 6. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

---

## Advanced Usage

### Scale Worker Nodes
Modify `variables.tf`:
```hcl
variable "worker_instance_count" {
  default = 5  # Increase from 2 to 5
}
```

Then:
```bash
terraform plan
terraform apply
```

### Change Instance Types
Modify `variables.tf`:
```hcl
variable "instance_type" {
  default = {
    master = "t2.large"   # Upgrade master
    worker = "t2.small"   # Upgrade workers
  }
}
```

Then:
```bash
terraform plan
terraform apply
```

### Access Kubernetes Dashboard

Deploy the dashboard:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create proxy
kubectl proxy

# Access at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `provider.tf` | AWS provider configuration |
| `variables.tf` | Input variables for customization |
| `main.tf` | EC2 instances (master & workers) |
| `sg.tf` | Security groups for network access |
| `keypair.tf` | SSH keypair generation |
| `outputs.tf` | Output values (IPs, configs) |
| `Master.sh` | Master node setup script |
| `Worker.sh` | Worker node setup script |
| `playbook.yml` | Ansible playbook for token fetch |
| `ansible.cfg` | Ansible configuration |

---

## Support & Issues

### Getting Help

1. **Check logs on nodes:**
   ```bash
   ssh -i k8s ubuntu@<NODE_IP>
   sudo journalctl -u kubelet -n 100
   ```

2. **Check Kubernetes events:**
   ```bash
   kubectl get events -A
   ```

3. **Check Terraform state:**
   ```bash
   terraform show
   ```

### Common Commands

```bash
# Terraform
terraform init          # Initialize Terraform
terraform plan          # Preview changes
terraform apply         # Apply changes
terraform destroy       # Destroy infrastructure
terraform output        # Show outputs

# Kubernetes
kubectl get nodes       # List nodes
kubectl get pods -A     # List all pods
kubectl describe node <NODE>  # Node details
kubectl logs <POD>      # Pod logs
kubectl exec -it <POD> -- sh  # Shell access to pod
```

---

## License

This project is open source and available under the MIT License.

---

## Author

**Shubham Saini**
- GitHub: [@shubham-saini18](https://github.com/shubham-saini18)

---

## Changelog

### v1.0.0 (2024)
- Initial release
- Terraform infrastructure code
- Ansible configuration management
- Support for Kubernetes 1.30+
- containerd runtime
- Weave networking plugin

---

## FAQ

### Q: What's the cost of running this cluster?

**A:** AWS charges approximately:
- Master (t2.medium): ~$0.047/hour
- 2x Workers (t2.micro): ~$0.012/hour each
- Total: ~$0.071/hour ≈ $52/month

Costs vary by region.

### Q: Can I add more worker nodes?

**A:** Yes! Update `variables.tf`:
```hcl
variable "worker_instance_count" {
  default = 5  # Increase number
}
```

Then run `terraform apply`.

### Q: How do I access the cluster from outside?

**A:** Copy the kubeconfig from the master:
```bash
scp -i k8s ubuntu@<MASTER_IP>:/home/ubuntu/.kube/config ./kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

### Q: What Kubernetes version is installed?

**A:** Currently v1.30. Check with:
```bash
kubectl version
```

### Q: Can I use a different CNI plugin?

**A:** Yes, but you need to modify `Master.sh` line 126 to use a different plugin (e.g., Calico, Flannel).

### Q: Is this production-ready?

**A:** This is suitable for **development and testing**. For production:
- Use managed Kubernetes (EKS)
- Implement backup and disaster recovery
- Use private subnets
- Enable monitoring and logging
- Set up ingress controllers
- Configure auto-scaling

---

**Happy clustering! 🚀**

