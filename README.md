# Aspire2Kube

> **From .NET Aspire to Kubernetes - Without a PhD in K8sology**

A command-line tool that simplifies the deployment of .NET Aspire applications to Kubernetes clusters, bridging the gap between Windows development and Linux server deployment.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![.NET](https://img.shields.io/badge/.NET-8.0-purple.svg)](https://dotnet.microsoft.com/download)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue.svg)]()

---

## 📖 Background

This project began as a personal journey from software development into the DevOps world—a quest to understand how Kubernetes really works in action with .NET projects. While [Aspirate](https://github.com/prom3theu5/aspirate) does an excellent job generating Kubernetes manifests from .NET Aspire orchestration, it was missing one crucial piece: **migration packaging**.

**The Problem:** Aspirate generates perfect Kubernetes manifests, but you still need to manually handle Docker images, secrets, transfer files, and set up the target environment. When you need to continuously deploy from one machine to another—whether that's Windows to Linux, Linux to Linux, or even Windows to Windows—the manual steps become tedious and error-prone.

**The Solution:** aspire2kube - a cross-platform tool designed to reduce the headache for developers who want to leverage Kubernetes without needing a PhD in "K8sology"! 

aspire2kube automates everything that comes **after** Aspirate:
- ✅ **Packages** Aspirate manifests into a migration bundle
- ✅ **Handles** Docker images (tar export or Docker Hub push)
- ✅ **Transfers** files to target server (SCP or croc P2P)
- ✅ **Initializes** Kubernetes on target (k3s or Minikube)
- ✅ **Deploys** with automatic secret decryption
- ✅ **Manages** cleanup and resource removal

This tool emerged from countless experiments, trial and error, and real-world deployment challenges—making Kubernetes migration as simple as running a few commands on **both Windows and Linux platforms**.

---

## ✨ Features

- 🚀 **One-Command Kubernetes Setup** - Install k3s or Minikube with all dependencies
- 🔄 **Cross-Platform Migration** - Package on any platform, deploy anywhere
- 🪟🐧 **Windows & Linux Support** - Full support for both operating systems
- 📦 **Flexible Image Export** - Choose between Docker Hub push or offline tar files
- 🔐 **Automatic Secret Management** - Decrypt and apply Aspire secrets automatically
- 🎯 **Interactive Cleanup** - Selectively remove resources when you're done
- 🐧 **Multi-Distribution Support** - Works on Ubuntu, Debian, Fedora, Rocky Linux, RHEL
- 🎮 **k3s or Minikube** - Choose your Kubernetes flavor
- 📊 **Built-in Monitoring** - Includes k9s and Kubernetes Dashboard

---

## 📋 Prerequisites

### Development Machine (Source - Windows or Linux)
- **.NET 8.0 SDK** or later
- **Docker Desktop** (Windows) or Docker (Linux)
- **.NET Aspire** application with AppHost project
- **Aspirate** tool: `dotnet tool install -g aspirate`

### Deployment Server (Target - Currently Linux, Windows Coming Soon)
- **Ubuntu 20.04+**, **Debian 11+**, **Fedora 37+**, or **Rocky Linux 8+**
- **Root or sudo access**
- **Internet connection** (for initial setup)

### Supported Migration Paths
- ✅ **Windows → Linux** (Generate on Windows, deploy on Linux)
- ✅ **Linux → Linux** (Generate and deploy on same or different Linux machines)
- ✅ **Windows → Windows** (Coming soon - Windows Server deployment)
- ✅ **Linux → Windows** (Coming soon - Windows Server deployment)

---

## 🚀 Quick Start

### Step 1: Install Tools

```bash
# Install Aspirate (generates Kubernetes manifests from Aspire)
dotnet tool install -g aspirate

# Install aspire2kube (packages everything for migration)
dotnet tool install -g aspire2kube
```

### Step 2: Generate Kubernetes Manifests with Aspirate

```bash
# Navigate to your Aspire AppHost project
cd MyAspireApp.AppHost

# Aspirate generates all Kubernetes manifests from your Aspire orchestration
aspirate generate --container-registry docker.io --image-pull-policy IfNotPresent

# This creates an 'aspirate-output' folder with deployment manifests
```

### Step 3: Package Migration Bundle with aspire2kube

```bash
# aspire2kube packages manifests + images into a migration-ready bundle

# Option 1: Package with tar images (offline deployment - images in zip)
aspire2kube generate --export-method tar --aspirate-output ./aspirate-output

# Option 2: Push images to Docker Hub (online deployment - smaller zip)
aspire2kube generate --export-method push --docker-username yourusername

# Option 3: Skip image handling (manifests only)
aspire2kube generate --export-method skip --aspirate-output ./aspirate-output

# This creates 'Aspire-Migration.zip' containing:
#   - manifests/ (from Aspirate output)
#   - *.tar files (if using tar method)
#   - deployment scripts
#   - secret decryption scripts
```

### Step 4: Transfer Migration Bundle to Target Server

```bash
# Option 1: Using SCP (SSH - traditional method)
scp Aspire-Migration.zip user@target-server:/home/user/

# Option 2: Using croc (easy P2P transfer, no SSH needed)
# Install croc: https://github.com/schollz/croc
croc send Aspire-Migration.zip
# On target server: croc [code-shown-by-sender]

# Extract on target server
unzip Aspire-Migration.zip
cd Aspire-Migration
```

### Step 5: Setup Kubernetes on Target Server

```bash
# On your target Linux server (SSH or local)
# Initialize Kubernetes (auto-detects distribution)
aspire2kube init

# Or specify distribution and k8s type
aspire2kube init --distro ubuntu --k8s-type k3s
```

### Step 6: Deploy Application

```bash
# From the extracted Aspire-Migration folder
cd Aspire-Migration
aspire2kube deploy
```

### Step 7: Verify Deployment

```bash
# Check running pods
kubectl get pods

# Check services
kubectl get services

# Use interactive management
k9s

# Access Kubernetes Dashboard
cat ~/k8s-dashboard-token.txt
# Open: https://target-server-ip:30443
```

---

## 📚 Complete Documentation

### Installation

#### Install as Global Tool
```bash
dotnet tool install -g aspire2kube
```

#### Update Existing Installation
```bash
dotnet tool update -g aspire2kube
```

#### Uninstall
```bash
dotnet tool uninstall -g aspire2kube
```

---

## 🎯 Command Reference

### `aspire2kube help`

Display comprehensive help information with all commands, options, and examples.

```bash
aspire2kube help
```

---

### `aspire2kube init`

Initialize Kubernetes environment by installing all prerequisites.

#### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--distro` | `-d` | Linux distribution (ubuntu, debian, fedora, rocky, rhel, auto) | `auto` |
| `--k8s-type` | `-k` | Kubernetes type (k3s, minikube) | `k3s` |

#### Supported Distributions

| Distribution | Package Manager | Notes |
|--------------|-----------------|-------|
| Ubuntu 20.04+ | apt | Fully tested |
| Debian 11+ | apt | Fully supported |
| Fedora 37+ | dnf | SELinux integrated |
| Rocky Linux 8+ | dnf | RHEL-compatible |
| RHEL 8+ | dnf | Uses Rocky scripts |
| CentOS Stream | dnf | Uses Rocky scripts |
| AlmaLinux 8+ | dnf | Uses Rocky scripts |

#### What Gets Installed

The `init` command installs:

- ✅ **Kubernetes** (k3s or Minikube)
- ✅ **kubectl** - Kubernetes command-line tool
- ✅ **k9s** - Terminal UI for Kubernetes
- ✅ **Kubernetes Dashboard** - Web-based UI
- ✅ **firewalld** - Firewall with Kubernetes ports configured
- ✅ **jq** - JSON processor for manifest parsing
- ✅ **Python3 + cryptography** - For secret decryption
- ✅ **Docker** (Minikube only) - Container runtime

#### Examples

```bash
# Auto-detect distribution and install k3s
aspire2kube init

# Install k3s on Ubuntu explicitly
aspire2kube init --distro ubuntu --k8s-type k3s

# Install Minikube on Fedora
aspire2kube init --distro fedora --k8s-type minikube

# Install on Rocky Linux with k3s
aspire2kube init -d rocky -k k3s
```

#### Post-Installation

After installation, you may need to:

1. **Restart your terminal** or run: `source ~/.bashrc`
2. **Log out/in if added to docker group** (Minikube): `newgrp docker`
3. **Verify installation**: `kubectl get nodes`

---

### `aspire2kube generate`

Package Kubernetes migration bundle from Aspirate output. This command takes the manifests generated by Aspirate and packages them along with Docker images into a ready-to-deploy bundle (zip file). **Note:** Aspirate must be run first to generate the Kubernetes manifests - this command packages them for migration.

#### Options

| Option | Description | Required |
|--------|-------------|----------|
| `--export-method` | Export method: `push`, `tar`, or `skip` | No (prompts) |
| `--aspirate-output` | Path to aspirate-output folder | No (prompts) |
| `--image` | Image name to export (can be repeated) | No (interactive) |
| `--docker-username` | Docker Hub username (required if method=push) | Conditional |

#### Export Methods

**1. `tar` - Offline Deployment** (Recommended for most users)
- Exports all Docker images as .tar files **included in the zip**
- No internet required on deployment server
- Best for air-gapped or restricted networks
- Larger zip file size (includes images)
- Images are automatically imported during deployment

```bash
aspire2kube generate --export-method tar
```

**2. `push` - Docker Hub Deployment**
- Pushes images to Docker Hub
- **Smaller zip file** (only manifests, no images)
- Requires Docker Hub account
- Requires internet on deployment server to pull images
- Faster transfer, images pulled during deployment

```bash
aspire2kube generate --export-method push --docker-username myusername
```

**3. `skip` - Manual Image Management**
- Skip image export/push entirely
- **Smallest zip file** (manifests only)
- Use if images are already available on target
- Advanced users only

```bash
aspire2kube generate --export-method skip
```

#### Output Structure

The command creates `Aspire-Migration.zip` containing:

```
Aspire-Migration.zip
└── Aspire-Migration/
    ├── manifests/                    (copied from aspirate-output)
    │   ├── my-api/
    │   │   ├── deployment.yaml
    │   │   ├── service.yaml
    │   │   ├── kustomization.yaml
    │   │   └── .my-api.secrets       (auto-generated during deploy)
    │   ├── my-web/
    │   │   └── ...
    │   └── sql-server/
    │       └── ...
    ├── *.tar                         (only if export-method=tar)
    ├── aspirate-state.json           (from aspirate-output)
    ├── deploy2k3s.sh                 (deployment script)
    ├── deploy2minikube.sh            (deployment script)
    └── decrypt-secrets.py            (secret decryption utility)
```

#### Transfer Options

The script can automatically transfer the zip to your target server:

**Option 1: SCP (SSH Transfer)**
```bash
# Requires SSH access to target server
# Script prompts for server details
# Uses secure SCP protocol
```

**Option 2: croc (P2P Transfer)**
```bash
# No SSH needed - uses relay servers
# Easy code-based pairing
# Works through firewalls
# Learn more: https://github.com/schollz/croc
```

**Option 3: Manual Transfer**
```bash
# Transfer Aspire-Migration.zip yourself
# Any method: USB, file share, cloud storage, etc.
```

#### Examples

```bash
# Interactive mode (prompts for everything)
aspire2kube generate

# Export as tar with specific path
aspire2kube generate \
  --export-method tar \
  --aspirate-output "C:\Projects\MyApp\aspirate-output"

# Push to Docker Hub
aspire2kube generate \
  --export-method push \
  --docker-username johndoe

# Select specific images to export
aspire2kube generate \
  --export-method tar \
  --image myapp-api:latest \
  --image myapp-web:latest \
  --image myapp-worker:latest
```

---

### `aspire2kube deploy`

Deploy Aspire application to Kubernetes cluster. This command runs on Linux server.

#### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--target` | `-t` | Kubernetes cluster (k3s, minikube) | `k3s` |

#### Prerequisites

Must be run from the `Aspire-Migration` folder with:
- ✅ `manifests/` directory
- ✅ `*.tar` files (if using tar export)
- ✅ `aspirate-state.json` (optional, for secrets)
- ✅ Kubernetes cluster running (`kubectl get nodes` should work)

#### What It Does

1. **Imports Docker Images** - Loads .tar files into cluster (if present)
2. **Processes Secrets** - Automatically decrypts Aspire secrets
3. **Applies Manifests** - Deploys all services using Kustomize
4. **Displays Status** - Shows pods, services, and access information

#### Secret Handling

The deploy script automatically handles encrypted secrets:
- Detects if secrets are encrypted
- Prompts for decryption password
- Creates `.secrets` files for each service
- Applies secrets to Kubernetes

#### Examples

```bash
# Deploy to k3s (default)
cd Aspire-Migration
aspire2kube deploy

# Deploy to Minikube
aspire2kube deploy --target minikube
aspire2kube deploy -t minikube
```

#### Troubleshooting Deployment

**Problem: "k3s command not found"**
```bash
# Solution: Restart terminal or reload bashrc
source ~/.bashrc
```

**Problem: "Permission denied"**
```bash
# Solution: Ensure KUBECONFIG is set
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

**Problem: "Secrets decryption failed"**
```bash
# Solution: Find password in aspirate-state.json
cat aspirate-state.json | jq -r '.secrets.masterPassword'
```

**Problem: "Images not found"**
```bash
# Solution: Check if .tar files are present or re-run generate
ls -la *.tar
```

---

### `aspire2kube destroy`

Interactive cleanup of Kubernetes resources. Safely remove deployed applications.

#### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--target` | `-t` | Kubernetes cluster (k3s, minikube) | `k3s` |

#### Cleanup Modes

**Mode 1: Delete ALL Resources** (Quick Cleanup)
- Removes everything in the namespace
- Fastest option
- Use when completely done with deployment

**Mode 2: Select Specific Resource Types**
- Interactive selection of what to delete
- Choose from:
  - Deployments
  - StatefulSets
  - DaemonSets
  - Services
  - Ingresses
  - ConfigMaps
  - Secrets
  - PersistentVolumeClaims
  - Jobs
  - CronJobs
  - Pods

**Mode 3: Preview Resources First**
- View all resources before deciding
- Shows current state
- Doesn't delete anything

**Mode 4: Minikube-Specific Operations** (Minikube only)
- Stop Minikube (preserve data)
- Delete Minikube cluster completely
- Delete & recreate (fresh start)
- Clean Docker images
- Reset addons
- View status & info

#### Examples

```bash
# Interactive cleanup (k3s)
aspire2kube destroy

# Cleanup Minikube resources
aspire2kube destroy --target minikube

# Set custom namespace
NAMESPACE=my-app aspire2kube destroy
```

#### Sample Interaction

```
================================================
  Interactive Cleanup - Remove Kubernetes Resources
================================================

Namespace: default

Checking resources in namespace...

Available resources:
  [3] Deployments
  [2] Services
  [1] Secrets
  [2] ConfigMaps
  [5] Pods

Select cleanup mode:
  1) Delete ALL resources in namespace (quick cleanup)
  2) Select specific resource types to delete
  3) Preview resources first
  4) Minikube-specific operations
  5) Cancel

Enter your choice (1-5): 2

Select resource types to delete:

Delete Deployments? (y/N): y
Delete Services? (y/N): y
Delete Secrets? (y/N): n
Delete ConfigMaps? (y/N): n
Delete Pods? (y/N): y

Resources selected for deletion:
  • Deployments
  • Services
  • Orphaned Pods

Proceed with deletion? (y/N): y

Deleting resources...

Deleting Deployments...
  ✓ Deployments deleted
Deleting Services...
  ✓ Services deleted
Deleting orphaned Pods...
  ✓ Pods deleted

=== Cleanup Complete ===
```

---

## 🔄 Complete Workflow Example

Here's a complete end-to-end example of deploying an Aspire application:

### On Your Development Machine (Windows or Linux)

```powershell
# 1. Create your .NET Aspire application
dotnet new aspire -n MyAspireApp
cd MyAspireApp

# 2. Build and test locally
dotnet build
dotnet run --project MyAspireApp.AppHost

# 3. Install required tools
dotnet tool install -g aspirate
dotnet tool install -g aspire2kube

# 4. Generate Kubernetes manifests with Aspirate
cd MyAspireApp.AppHost
aspirate generate --container-registry docker.io

# 5. Package everything into migration bundle
aspire2kube generate --export-method tar --aspirate-output ./aspirate-output
# This creates Aspire-Migration.zip with manifests, tar images, and scripts

# 6. Transfer to target server

# Option A: Using SCP (SSH)
scp Aspire-Migration.zip user@target-server:/home/user/

# Option B: Using croc (P2P, no SSH needed)
croc send Aspire-Migration.zip
# On target server: croc [code-shown-here]

# Option C: Manual transfer
# Copy Aspire-Migration.zip using any method you prefer
```

### On Your Target Linux Server (or same machine)

```bash
# 1. Extract the migration bundle
unzip Aspire-Migration.zip
cd Aspire-Migration

# 2. Install aspire2kube (if not already installed)
dotnet tool install -g aspire2kube

# 3. Initialize Kubernetes environment
aspire2kube init

# 4. Restart terminal or reload
source ~/.bashrc

# 5. Verify Kubernetes is running
kubectl get nodes

# 6. Deploy application (from Aspire-Migration folder)
aspire2kube deploy

# 7. Check deployment status
kubectl get pods
kubectl get services

# 8. Access Kubernetes Dashboard
cat ~/k8s-dashboard-token.txt
# Open: https://localhost:30443 or https://server-ip:30443

# 9. Use k9s for interactive management
k9s
```

### Updating Your Application

```bash
# On development machine: Re-generate bundle
cd MyAspireApp.AppHost
aspirate generate --container-registry docker.io
aspire2kube generate --export-method tar

# Transfer Aspire-Migration.zip to server (SCP, croc, or manual)
scp Aspire-Migration.zip user@target-server:/home/user/

# On target server: Extract and re-deploy
unzip -o Aspire-Migration.zip
cd Aspire-Migration
aspire2kube deploy
```

### Cleanup

```bash
# On target server: Remove deployed resources
aspire2kube destroy
# Select Mode 1 for complete cleanup

# Optional: Uninstall Kubernetes (Linux only)
sudo /usr/local/bin/k3s-uninstall.sh
```

---

## 🎓 Understanding the Architecture

### k3s vs Minikube

| Feature | k3s | Minikube |
|---------|-----|----------|
| **Purpose** | Production-ready lightweight k8s | Development/testing |
| **Installation** | Native (no VM) | VM-based (Docker) |
| **Resource Usage** | ~512MB RAM | ~2GB RAM minimum |
| **Startup Time** | Seconds | ~1 minute |
| **Persistence** | Always running | Start/stop as needed |
| **Best For** | Servers, IoT, production | Local dev, testing |
| **Addons** | Manual kubectl | `minikube addons` |
| **Access** | Direct IP | `minikube service` |

**Recommendation:**
- **Use k3s** for: Production servers, always-on environments, minimal resources
- **Use Minikube** for: Development, testing, learning, disposable clusters

### Image Export Methods

#### Tar Export (Offline)

**Pros:**
- ✅ Works in air-gapped environments
- ✅ No Docker Hub account needed
- ✅ No internet required on server
- ✅ Complete control over images

**Cons:**
- ❌ Larger transfer size (hundreds of MB)
- ❌ Manual re-transfer for updates
- ❌ Takes longer to generate

**Use When:**
- Deploying to restricted networks
- No Docker Hub account
- Security requires offline deployment
- Bandwidth is not an issue

#### Docker Hub Push (Online)

**Pros:**
- ✅ Smaller transfer size (manifests only)
- ✅ Easier updates (just pull new images)
- ✅ Standard Docker workflow
- ✅ Can use existing CI/CD

**Cons:**
- ❌ Requires Docker Hub account
- ❌ Requires internet on server
- ❌ Images are public (or paid private repos)
- ❌ External dependency

**Use When:**
- Server has good internet
- Using Docker Hub workflow
- Need frequent updates
- Size of transfer matters

### Transfer Methods

aspire2kube supports two methods for transferring the migration bundle to your target server:

#### SCP (SSH Copy Protocol)

**How it works:**
- Traditional SSH-based file transfer
- Requires SSH access to target server
- Built into all Linux/macOS, available on Windows

**Pros:**
- ✅ Standard, well-known protocol
- ✅ Secure encryption
- ✅ Works on any server with SSH
- ✅ No additional tools needed

**Cons:**
- ❌ Requires SSH setup
- ❌ Need server credentials
- ❌ May require port forwarding

**Use When:**
- You have SSH access
- Deploying to servers
- Standard enterprise environment

**Example:**
```bash
scp Aspire-Migration.zip user@server-ip:/home/user/
```

#### croc (P2P File Transfer)

**How it works:**
- Peer-to-peer file transfer using relay servers
- No SSH needed - just a code phrase
- Works through firewalls and NAT

**Pros:**
- ✅ No SSH setup required
- ✅ Works through firewalls
- ✅ Simple code-based pairing
- ✅ End-to-end encrypted
- ✅ Cross-platform (Windows/Linux/macOS)

**Cons:**
- ❌ Requires croc installed on both sides
- ❌ Relies on relay servers
- ❌ May be slower than direct SCP

**Use When:**
- No SSH access available
- Quick transfers between machines
- Working through restrictive firewalls
- Transferring to developer workstations

**Example:**
```bash
# On source machine
croc send Aspire-Migration.zip
# Shows code like: "code is: 8765-tennis-table-quick"

# On target machine
croc 8765-tennis-table-quick
# Receives the file
```

**Installation:**
- Linux: `curl https://getcroc.schollz.com | bash`
- Windows: `scoop install croc` or download from [GitHub](https://github.com/schollz/croc/releases)
- More info: https://github.com/schollz/croc

---

## 🔐 Security Considerations

### Secrets Management

aspire2kube handles secrets through the Aspirate state file:

1. **Encryption**: Aspirate encrypts secrets with AES-256-GCM
2. **Storage**: Encrypted secrets stored in `aspirate-state.json`
3. **Decryption**: Deploy script automatically decrypts using provided password
4. **Application**: Secrets applied as Kubernetes secrets in cluster

**Best Practices:**
- ✅ Keep `aspirate-state.json` secure
- ✅ Use strong passwords for secret encryption
- ✅ Transfer files over secure channels (SSH/SCP)
- ✅ Delete migration folder after deployment
- ✅ Rotate secrets regularly in production

### Kubernetes Dashboard Access

The dashboard is exposed on port 30443 with token authentication:

**Secure Access Methods:**

1. **SSH Tunnel** (Most Secure)
```bash
ssh -L 8443:localhost:30443 user@your-server
# Access: https://localhost:8443
```

2. **Firewall Restriction** (Production)
```bash
# Allow only your IP
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="YOUR-IP" port port="30443" protocol="tcp" accept'
sudo firewall-cmd --reload
```

3. **VPN Access** (Enterprise)
- Access server through VPN
- Dashboard not exposed to internet

### Firewall Configuration

The `init` command automatically configures firewall rules:

```bash
# Kubernetes API: 6443
# Kubelet: 10250
# Dashboard: 30443
# NodePort range: 30000-32767
# Your services: 80, 443, custom ports
```

Review with: `sudo firewall-cmd --list-all`

---

## 🐛 Troubleshooting

### Common Issues and Solutions

#### 1. "Command not found" after init

**Symptom:** Running `kubectl` or `k3s` results in "command not found"

**Solutions:**
```bash
# Reload bashrc
source ~/.bashrc

# Or restart terminal
exit
# SSH back in

# Verify PATH
echo $PATH | grep -o "/usr/local/bin"

# Manually export if needed
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

#### 2. Permission denied - kubectl

**Symptom:** `kubectl get nodes` returns permission errors

**Solutions:**
```bash
# Ensure KUBECONFIG is set
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check k3s is running
sudo systemctl status k3s

# Check file permissions
ls -la /etc/rancher/k3s/k3s.yaml

# Copy to user directory
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

#### 3. Docker permission denied (Minikube)

**Symptom:** `permission denied while trying to connect to the Docker daemon`

**Solutions:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes without logout
newgrp docker

# Or logout and back in
exit
# SSH back in

# Verify
docker ps
```

#### 4. Secrets decryption fails

**Symptom:** Deploy script cannot decrypt secrets

**Solutions:**
```bash
# Find master password
cat aspirate-state.json | jq -r '.secrets.masterPassword'

# Or check metadata section
cat aspirate-state.json | jq '.secrets'

# Verify Python cryptography
python3 -c "import cryptography; print('OK')"

# Reinstall if needed
pip3 install --break-system-packages cryptography
```

#### 5. Pods stuck in "ImagePullBackOff"

**Symptom:** Pods cannot pull images

**Solutions:**

**For tar export:**
```bash
# Verify images are imported
sudo k3s crictl images

# Check .tar files exist
ls -la *.tar

# Re-import manually
sudo k3s ctr -n k8s.io images import my-image.tar
```

**For Docker Hub push:**
```bash
# Verify image name in manifest
kubectl get deployment my-app -o yaml | grep image

# Check image exists on Docker Hub
docker pull yourusername/my-image:latest

# Update imagePullPolicy
kubectl patch deployment my-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"my-container","imagePullPolicy":"Always"}]}}}}'
```

#### 6. Minikube won't start

**Symptom:** `minikube start` fails or times out

**Solutions:**
```bash
# Check status
minikube status

# Delete and recreate
minikube delete
minikube start --driver=docker --cpus=2 --memory=4096

# Check Docker
docker ps
systemctl status docker

# Check logs
minikube logs

# Try different driver
minikube start --driver=none  # Not recommended
```

#### 7. SELinux permission errors (Fedora/RHEL)

**Symptom:** Pods fail with permission errors on Fedora/RHEL

**Solutions:**
```bash
# Check SELinux denials
sudo ausearch -m avc -ts recent

# Verify k3s-selinux is installed
rpm -q k3s-selinux

# Check SELinux status
getenforce

# Temporarily set permissive (testing only)
sudo setenforce 0

# Check logs
journalctl -u k3s -f
```

#### 8. Dashboard not accessible

**Symptom:** Cannot access dashboard at https://server-ip:30443

**Solutions:**
```bash
# Verify dashboard is running
kubectl get pods -n kubernetes-dashboard

# Check service
kubectl get svc -n kubernetes-dashboard

# Verify firewall
sudo firewall-cmd --list-ports | grep 30443

# Add port if missing
sudo firewall-cmd --permanent --add-port=30443/tcp
sudo firewall-cmd --reload

# Get token
cat ~/k8s-dashboard-token.txt

# Use SSH tunnel
ssh -L 8443:localhost:30443 user@your-server
# Access: https://localhost:8443
```

#### 9. Services not accessible from outside

**Symptom:** Cannot access services via NodePort from external machine

**Solutions:**
```bash
# Check service type
kubectl get svc

# Get NodePort
kubectl get svc my-service -o jsonpath='{.spec.ports[0].nodePort}'

# Test locally
curl http://localhost:NODE_PORT

# Check firewall
sudo firewall-cmd --list-ports

# Add NodePort range if missing
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo firewall-cmd --reload

# For Minikube, use minikube service
minikube service my-service --url
```

#### 10. Out of disk space

**Symptom:** Pods fail with disk pressure errors

**Solutions:**
```bash
# Check disk usage
df -h

# For k3s
# Clean unused images
sudo k3s crictl rmi --prune

# For Minikube
minikube ssh -- docker system prune -a

# Remove old deployments
kubectl delete deployment old-deployment

# Clean PVCs
kubectl delete pvc --all
```

### Getting Help

If you encounter issues not covered here:

1. **Check logs:**
   ```bash
   # k3s logs
   sudo journalctl -u k3s -f
   
   # Pod logs
   kubectl logs <pod-name>
   
   # Minikube logs
   minikube logs
   ```

2. **Describe resources:**
   ```bash
   kubectl describe pod <pod-name>
   kubectl describe deployment <deployment-name>
   ```

3. **Use k9s for investigation:**
   ```bash
   k9s
   # Press '?' for help
   # Navigate with arrow keys
   # Press 'l' to view logs
   ```

4. **Open an issue:**
   - [GitHub Issues](https://github.com/your-repo/aspire2kube/issues)
   - Include: OS, k8s type, error messages, relevant logs

---

## 📊 Useful Kubernetes Commands

### Basic Operations

```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes

# View all resources
kubectl get all
kubectl get all -A  # All namespaces

# Specific resources
kubectl get pods
kubectl get services
kubectl get deployments
kubectl get pvc  # Persistent Volume Claims
```

### Detailed Information

```bash
# Describe resource
kubectl describe pod <pod-name>
kubectl describe service <service-name>

# View logs
kubectl logs <pod-name>
kubectl logs <pod-name> -f  # Follow logs
kubectl logs <pod-name> --previous  # Previous container logs

# Execute commands in pod
kubectl exec -it <pod-name> -- bash
kubectl exec -it <pod-name> -- sh
```

### Resource Management

```bash
# Scale deployments
kubectl scale deployment <name> --replicas=3

# Update image
kubectl set image deployment/<name> <container>=<new-image>

# Restart deployment
kubectl rollout restart deployment/<name>

# Check rollout status
kubectl rollout status deployment/<name>

# Rollback
kubectl rollout undo deployment/<name>
```

### Port Forwarding

```bash
# Forward pod port to local
kubectl port-forward pod/<pod-name> 8080:80

# Forward service port
kubectl port-forward service/<service-name> 8080:80

# Listen on all interfaces
kubectl port-forward --address 0.0.0.0 service/<service-name> 8080:80
```

### Debugging

```bash
# Get events
kubectl get events
kubectl get events --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods

# Run temporary debug pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
```

### k3s Specific

```bash
# Check k3s status
sudo systemctl status k3s

# Restart k3s
sudo systemctl restart k3s

# View k3s logs
sudo journalctl -u k3s -f

# Check installed images
sudo k3s crictl images

# Import image manually
sudo k3s ctr -n k8s.io images import image.tar

# Remove image
sudo k3s crictl rmi <image-id>
```

### Minikube Specific

```bash
# Check Minikube status
minikube status

# Start/Stop
minikube start
minikube stop

# Access service
minikube service <service-name>
minikube service <service-name> --url

# SSH into Minikube
minikube ssh

# Addons
minikube addons list
minikube addons enable <addon>
minikube addons disable <addon>

# Dashboard
minikube dashboard

# Get Minikube IP
minikube ip

# Clean up
minikube delete
```

---

## 🤝 Contributing

Contributions are welcome! Whether it's bug reports, feature requests, or code contributions.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Setup

```bash
# Clone repository
git clone https://github.com/your-repo/aspire2kube.git
cd aspire2kube

# Build
dotnet build

# Run locally
dotnet run -- help

# Pack
dotnet pack

# Install locally for testing
dotnet tool install --global --add-source ./nupkg aspire2kube
```

### Areas for Contribution

- 🐛 Bug fixes
- 📝 Documentation improvements
- ✨ New features
- 🧪 Test coverage
- 🌍 Additional Linux distribution support
- 💻 Windows deployment support
- 🔧 Tool improvements

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **[Aspirate](https://github.com/prom3theu5/aspirate)** - The excellent tool that generates Kubernetes manifests from .NET Aspire
- **[.NET Aspire](https://learn.microsoft.com/dotnet/aspire)** - Microsoft's cloud-native development stack
- **[k3s](https://k3s.io/)** - Lightweight Kubernetes distribution
- **[Minikube](https://minikube.sigs.k8s.io/)** - Local Kubernetes development
- **[k9s](https://k9scli.io/)** - Terminal UI for Kubernetes

---

## 📞 Support

- **Documentation**: [GitHub Wiki](https://github.com/your-repo/aspire2kube/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-repo/aspire2kube/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/aspire2kube/discussions)

---

## 🗺️ Roadmap

### Current Version (v1.0)
- ✅ Multi-distribution Linux support
- ✅ k3s and Minikube support
- ✅ Tar and Docker Hub image export
- ✅ Automatic secret decryption
- ✅ Interactive cleanup

### Planned Features
- 🔜 Windows Server deployment support
- 🔜 Helm chart generation option
- 🔜 CI/CD pipeline templates
- 🔜 Health check automation
- 🔜 Monitoring stack integration (Prometheus/Grafana)
- 🔜 Log aggregation setup
- 🔜 Multi-cluster deployment
- 🔜 Blue-green deployment support

---

## 💡 Tips and Best Practices

### Development Workflow

1. **Use Minikube for local testing** before deploying to k3s
2. **Version your images** with tags like `v1.0.0`, not just `latest`
3. **Test deployments** in a separate namespace first
4. **Keep secrets secure** - never commit `aspirate-state.json`
5. **Use resource limits** in production deployments

### Production Deployment

1. **Use k3s** for production servers
2. **Enable firewall** and restrict access
3. **Regular backups** of persistent volumes
4. **Monitor resources** with `kubectl top`
5. **Set up alerts** for pod failures
6. **Use SSH tunnels** for dashboard access
7. **Rotate secrets** regularly
8. **Keep cluster updated**: `sudo /usr/local/bin/k3s-killall.sh && curl -sfL https://get.k3s.io | sh -`

### Cost Optimization

1. **Right-size resources** - Don't over-provision
2. **Use HPA** (Horizontal Pod Autoscaler) for variable loads
3. **Clean up unused resources** regularly
4. **Remove old images** to save disk space
5. **Monitor usage** to identify optimization opportunities

---

<div align="center">

**Made with ❤️ by developers, for developers**

*No PhD in K8sology required!*

</div>