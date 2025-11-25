#!/bin/bash

# Prerequisites Installation Script for Rocky Linux
# Installs: kubectl, k9s, k3s OR minikube, Kubernetes Dashboard, Lens (optional), .NET SDK, Aspirate, mssql-tools

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

echo "================================================"
echo "  Installing Kubernetes Prerequisites"
echo "================================================"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}[1/9] Updating system...${NC}"
sudo dnf update -y
echo -e "${GREEN}System updated${NC}"
echo ""

# Choose Kubernetes implementation
echo -e "${YELLOW}[2/9] Choose Kubernetes implementation:${NC}"
echo -e "${CYAN}1) k3s (Lightweight Kubernetes, recommended for production)${NC}"
echo -e "${CYAN}2) minikube (Development focused, single-node cluster)${NC}"
echo ""
read -p "Enter your choice (1 or 2): " K8S_CHOICE

while [[ ! "$K8S_CHOICE" =~ ^[12]$ ]]; do
    echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
    read -p "Enter your choice (1 or 2): " K8S_CHOICE
done

if [ "$K8S_CHOICE" == "1" ]; then
    K8S_TYPE="k3s"
    echo -e "${GREEN}Selected: k3s${NC}"
else
    K8S_TYPE="minikube"
    echo -e "${GREEN}Selected: minikube${NC}"
fi
echo ""

# Install kubectl
echo -e "${YELLOW}[3/9] Installing kubectl...${NC}"

# Refresh PATH
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}kubectl already installed${NC}"
    kubectl version --client 2>/dev/null || kubectl version --client --short 2>/dev/null || echo "kubectl found"
else
    echo -e "${CYAN}Downloading kubectl...${NC}"
    
    cd /tmp
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    if [ -f kubectl ]; then
        chmod +x kubectl
        mv kubectl /usr/local/bin/kubectl
        
        # Verify installation
        if [ -f /usr/local/bin/kubectl ]; then
            echo -e "${GREEN}kubectl installed successfully${NC}"
            /usr/local/bin/kubectl version --client 2>/dev/null || echo "kubectl is ready"
        else
            echo -e "${RED}kubectl installation failed${NC}"
        fi
    else
        echo -e "${RED}kubectl download failed${NC}"
    fi
fi
echo ""

# Install k9s
echo -e "${YELLOW}[4/9] Installing k9s...${NC}"

if command -v k9s &> /dev/null; then
    echo -e "${GREEN}k9s already installed${NC}"
    k9s version 2>/dev/null || echo "k9s found"
else
    echo -e "${CYAN}Downloading k9s...${NC}"
    
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -oP '"tag_name": "\K[^"]+' || echo "v0.32.5")
    if [ -z "$K9S_VERSION" ]; then
        K9S_VERSION="v0.32.5"
    fi
    
    cd /tmp
    wget -q --show-progress "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" || {
        echo -e "${RED}k9s download failed${NC}"
        K9S_VERSION="v0.32.5"
        wget -q --show-progress "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
    }
    
    if [ -f k9s_Linux_amd64.tar.gz ]; then
        tar -xzf k9s_Linux_amd64.tar.gz
        chmod +x k9s
        mv k9s /usr/local/bin/
        rm -f k9s_Linux_amd64.tar.gz LICENSE README.md
        
        # Verify installation
        if [ -f /usr/local/bin/k9s ]; then
            echo -e "${GREEN}k9s installed successfully${NC}"
        else
            echo -e "${RED}k9s installation failed${NC}"
        fi
    else
        echo -e "${RED}k9s download failed${NC}"
    fi
fi
echo ""

# Install either k3s or minikube based on user choice
echo -e "${YELLOW}[5/9] Installing $K8S_TYPE (Kubernetes cluster)...${NC}"

if [ "$K8S_TYPE" == "k3s" ]; then
    # Install k3s
    if command -v k3s &> /dev/null; then
        echo -e "${GREEN}k3s already installed${NC}"
        k3s --version
    else
        echo -e "${CYAN}Installing k3s...${NC}"
        curl -sfL https://get.k3s.io | sh -
        
        # Wait for k3s to be ready
        echo -e "${CYAN}Waiting for k3s to be ready...${NC}"
        sleep 10
        
        # Configure kubectl to use k3s
        mkdir -p ~/.kube
        cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
        chmod 600 ~/.kube/config
        
        # Set KUBECONFIG environment variable
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        if ! grep -q "KUBECONFIG=/etc/rancher/k3s/k3s.yaml" /root/.bashrc; then
            echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /root/.bashrc
        fi
        
        # Also configure for sudo user
        if [ "$SUDO_USER" ]; then
            SUDO_HOME=$(eval echo ~$SUDO_USER)
            mkdir -p "$SUDO_HOME/.kube"
            cp /etc/rancher/k3s/k3s.yaml "$SUDO_HOME/.kube/config"
            chown -R $SUDO_USER:$SUDO_USER "$SUDO_HOME/.kube"
            chmod 600 "$SUDO_HOME/.kube/config"
            
            if ! grep -q "KUBECONFIG" "$SUDO_HOME/.bashrc" 2>/dev/null; then
                echo "export KUBECONFIG=$SUDO_HOME/.kube/config" >> "$SUDO_HOME/.bashrc"
            fi
        fi
        
        if command -v k3s &> /dev/null; then
            echo -e "${GREEN}k3s installed successfully${NC}"
            k3s --version
        else
            echo -e "${RED}k3s installation failed${NC}"
        fi
    fi
else
    # Install minikube
    if command -v minikube &> /dev/null; then
        echo -e "${GREEN}minikube already installed${NC}"
        minikube version
    else
        echo -e "${CYAN}Installing dependencies for minikube...${NC}"
        
        # Install required packages
        dnf install -y conntrack socat
        
        # Check if running in a VM or physical machine
        if systemctl is-active --quiet libvirtd || grep -E '(vmx|svm)' /proc/cpuinfo > /dev/null; then
            echo -e "${CYAN}Installing KVM/libvirt for minikube (VM driver)...${NC}"
            dnf install -y qemu-kvm libvirt libvirt-daemon-kvm
            systemctl start libvirtd
            systemctl enable libvirtd
            MINIKUBE_DRIVER="kvm2"
        else
            echo -e "${YELLOW}No virtualization detected, will use Docker or Podman driver${NC}"
            # Install Podman as an alternative to Docker
            echo -e "${CYAN}Installing Podman for minikube...${NC}"
            dnf install -y podman podman-docker
            systemctl start podman.socket
            systemctl enable podman.socket
            MINIKUBE_DRIVER="podman"
        fi
        
        echo -e "${CYAN}Downloading minikube...${NC}"
        cd /tmp
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        
        if [ -f minikube-linux-amd64 ]; then
            chmod +x minikube-linux-amd64
            mv minikube-linux-amd64 /usr/local/bin/minikube
            
            # Verify installation
            if [ -f /usr/local/bin/minikube ] && command -v minikube &> /dev/null; then
                echo -e "${GREEN}minikube installed successfully${NC}"
                minikube version
                
                # Start minikube
                echo -e "${CYAN}Starting minikube cluster with $MINIKUBE_DRIVER driver...${NC}"
                minikube start --driver=$MINIKUBE_DRIVER
                
                # Configure kubectl
                echo -e "${CYAN}Configuring kubectl for minikube...${NC}"
                minikube kubectl -- get pods -A > /dev/null 2>&1
                
                # Setup kubeconfig
                mkdir -p ~/.kube
                minikube update-context
                
                # Also configure for sudo user
                if [ "$SUDO_USER" ]; then
                    SUDO_HOME=$(eval echo ~$SUDO_USER)
                    sudo -u $SUDO_USER minikube update-context 2>/dev/null || true
                fi
                
                echo -e "${GREEN}minikube cluster started successfully${NC}"
                minikube status
            else
                echo -e "${RED}minikube installation failed${NC}"
            fi
        else
            echo -e "${RED}minikube download failed${NC}"
        fi
    fi
fi
echo ""

# Install Kubernetes Dashboard
echo -e "${YELLOW}[6/9] Installing Kubernetes Dashboard...${NC}"

# Only makes sense on a machine with a graphical desktop
GUI_AVAILABLE=false

if command -v systemctl &> /dev/null; then
    # If default target is graphical, assume we have a GUI
    if systemctl get-default 2>/dev/null | grep -q "graphical.target"; then
        GUI_AVAILABLE=true
    fi
fi

if [ "$GUI_AVAILABLE" != "true" ]; then
    echo -e "${GRAY}No graphical desktop detected (default target is not 'graphical').${NC}"
    echo -e "${GRAY}Skipping Kubernetes Dashboard installation.${NC}"
else
    # Set KUBECONFIG based on the chosen implementation
    if [ "$K8S_TYPE" == "k3s" ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    fi

    if kubectl get namespace kubernetes-dashboard &> /dev/null; then
        echo -e "${GREEN}Kubernetes Dashboard already installed${NC}"
    else
        echo -e "${CYAN}Deploying Kubernetes Dashboard...${NC}"
        
        # Apply the official dashboard manifest
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
        
        echo -e "${CYAN}Waiting for dashboard pods to be ready...${NC}"
        sleep 5
        
        # Create admin service account
        echo -e "${CYAN}Creating admin service account...${NC}"
        
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
        
        echo -e "${CYAN}Waiting for service account to be created...${NC}"
        sleep 3
        
        # Create token for admin user
        echo -e "${CYAN}Generating access token...${NC}"
        DASHBOARD_TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user --duration=87600h 2>/dev/null || echo "")
        
        if [ -n "$DASHBOARD_TOKEN" ]; then
            # Save token to file
            echo "$DASHBOARD_TOKEN" > /root/k8s-dashboard-token.txt
            chmod 600 /root/k8s-dashboard-token.txt
            
            if [ "$SUDO_USER" ]; then
                SUDO_HOME=$(eval echo ~$SUDO_USER)
                echo "$DASHBOARD_TOKEN" > "$SUDO_HOME/k8s-dashboard-token.txt"
                chown $SUDO_USER:$SUDO_USER "$SUDO_HOME/k8s-dashboard-token.txt"
                chmod 600 "$SUDO_HOME/k8s-dashboard-token.txt"
            fi
            
            echo -e "${GREEN}Dashboard token saved to k8s-dashboard-token.txt${NC}"
        fi
        
        # Configure dashboard access based on k8s type
        if [ "$K8S_TYPE" == "k3s" ]; then
            # Patch dashboard service to use NodePort
            echo -e "${CYAN}Configuring dashboard access for k3s...${NC}"
            kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard --type='json' -p \
'[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"add","path":"/spec/ports/0/nodePort","value":30443}]' \
2>/dev/null || {
                echo -e "${YELLOW}Dashboard service may already be configured${NC}"
            }
            DASHBOARD_URL="https://localhost:30443"
        else
            # For minikube, we'll use port-forwarding
            echo -e "${CYAN}Dashboard will be accessible via minikube dashboard command or port-forward${NC}"
            DASHBOARD_URL="Use: minikube dashboard or kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443"
        fi
        
        echo -e "${GREEN}Kubernetes Dashboard installed successfully${NC}"
        echo ""
        echo -e "${CYAN}Dashboard access: $DASHBOARD_URL${NC}"
        echo -e "${CYAN}Use the token from: k8s-dashboard-token.txt${NC}"
    fi
fi
echo ""

# Lens installation (optional)
echo -e "${YELLOW}[7/9] Lens installation (Kubernetes IDE)...${NC}"

# Only makes sense on machines with a graphical desktop
LENS_GUI_AVAILABLE=false

if command -v systemctl &> /dev/null; then
    if systemctl get-default 2>/dev/null | grep -q "graphical.target"; then
        LENS_GUI_AVAILABLE=true
    fi
fi

if [ "$LENS_GUI_AVAILABLE" != "true" ]; then
    echo -e "${GRAY}No graphical desktop detected (default target is not 'graphical').${NC}"
    echo -e "${GRAY}Skipping Lens installation.${NC}"
else
    read -p "Do you want to install Lens? (y/n): " INSTALL_LENS

    if [[ "$INSTALL_LENS" =~ ^[Yy]$ ]]; then
        if [ -f "/usr/local/bin/lens" ]; then
            echo -e "${GREEN}Lens already installed${NC}"
        else
            echo -e "${CYAN}Downloading Lens (OpenLens)...${NC}"
            
            cd /tmp
            # Get latest OpenLens release
            LENS_VERSION=$(curl -s https://api.github.com/repos/MuhammedKalkan/OpenLens/releases/latest | grep -oP '"tag_name": "\K[^"]+' || echo "v6.5.2-366")
            if [ -z "$LENS_VERSION" ]; then
                LENS_VERSION="v6.5.2-366"
            fi
            
            wget -q --show-progress "https://github.com/MuhammedKalkan/OpenLens/releases/download/${LENS_VERSION}/OpenLens-${LENS_VERSION#v}.x86_64.AppImage" || {
                echo -e "${YELLOW}Trying fallback version...${NC}"
                wget -q --show-progress "https://github.com/MuhammedKalkan/OpenLens/releases/download/v6.5.2-366/OpenLens-6.5.2-366.x86_64.AppImage"
                LENS_VERSION="v6.5.2-366"
            }

            if [ -f "OpenLens-${LENS_VERSION#v}.x86_64.AppImage" ]; then
                chmod +x "OpenLens-${LENS_VERSION#v}.x86_64.AppImage"
                mv "OpenLens-${LENS_VERSION#v}.x86_64.AppImage" /usr/local/bin/lens
                
                # Create desktop entry
                cat > /usr/share/applications/lens.desktop <<EOF
[Desktop Entry]
Name=Lens
Exec=/usr/local/bin/lens
Type=Application
Categories=Development;
Comment=Kubernetes IDE
Terminal=false
EOF
                
                echo -e "${GREEN}Lens installed successfully${NC}"
            else
                echo -e "${RED}Lens download failed${NC}"
            fi
        fi
    else
        echo -e "${GRAY}Skipping Lens installation${NC}"
    fi
fi
echo ""

# Install mssql-tools (SQL Server command line tools)
echo -e "${YELLOW}[8/9] Installing mssql-tools (SQL Server command line tools)...${NC}"

if command -v sqlcmd &> /dev/null || [ -f /opt/mssql-tools/bin/sqlcmd ]; then
    echo -e "${GREEN}mssql-tools already installed${NC}"
    sqlcmd -? 2>&1 | head -n 1 || echo "sqlcmd found"
else
    echo -e "${CYAN}Importing Microsoft GPG key...${NC}"
    rpm --import https://packages.microsoft.com/keys/microsoft.asc || {
        echo -e "${RED}Failed to import Microsoft GPG key${NC}"
    }

    echo -e "${CYAN}Detecting Rocky Linux major version...${NC}"
    OS_MAJOR=$(grep -oP '(?<=^VERSION_ID=\")([0-9]+)' /etc/os-release 2>/dev/null || echo 9)

    if [ "$OS_MAJOR" -lt 9 ]; then
        RHEL_VER=8
    else
        RHEL_VER=9
    fi

    echo -e "${CYAN}Using Microsoft repo for RHEL ${RHEL_VER} (Rocky ${OS_MAJOR})...${NC}"

    tee /etc/yum.repos.d/msprod.repo > /dev/null << EOF
[packages-microsoft-com-mssql-server]
name=Microsoft SQL Server
baseurl=https://packages.microsoft.com/rhel/${RHEL_VER}/mssql-server-2025
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc

[packages-microsoft-com-mssql-tools]
name=Microsoft SQL Server Tools
baseurl=https://packages.microsoft.com/rhel/${RHEL_VER}/prod
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

    echo -e "${CYAN}Updating repository cache...${NC}"
    dnf update -y

    echo -e "${CYAN}Installing mssql-tools and unixODBC...${NC}"
    ACCEPT_EULA=Y dnf install -y mssql-tools unixODBC-devel || {
        echo -e "${RED}mssql-tools installation failed${NC}"
    }

    # Add mssql-tools to PATH for root
    MSSQL_TOOLS_PATH="/opt/mssql-tools/bin"
    if [[ -d "$MSSQL_TOOLS_PATH" ]]; then
        if [[ ":$PATH:" != *":$MSSQL_TOOLS_PATH:"* ]]; then
            echo "export PATH=\"\$PATH:$MSSQL_TOOLS_PATH\"" >> /root/.bashrc
            export PATH="$PATH:$MSSQL_TOOLS_PATH"
        fi

        # Add for current user if not root
        if [ "$SUDO_USER" ]; then
            SUDO_HOME=$(eval echo ~$SUDO_USER)
            if ! grep -q "mssql-tools" "$SUDO_HOME/.bashrc" 2>/dev/null; then
                echo "export PATH=\"\$PATH:$MSSQL_TOOLS_PATH\"" >> "$SUDO_HOME/.bashrc"
            fi
        fi
    fi

    # Verify installation
    if command -v sqlcmd &> /dev/null || [ -f /opt/mssql-tools/bin/sqlcmd ]; then
        echo -e "${GREEN}mssql-tools installed successfully${NC}"
        echo -e "${GRAY}Tools installed: sqlcmd, bcp${NC}"
        echo -e "${GRAY}Location: /opt/mssql-tools/bin/${NC}"
        echo -e "${GRAY}Restart terminal or run: source ~/.bashrc${NC}"
    else
        echo -e "${RED}mssql-tools installation failed${NC}"
    fi
fi
echo ""


# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=30000-32767/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=6443/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=80/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=30443/tcp 2>/dev/null || true  # Dashboard
    firewall-cmd --permanent --add-port=8443/tcp 2>/dev/null || true   # Dashboard port-forward
    firewall-cmd --reload 2>/dev/null || true
    echo -e "${GREEN}Firewall configured${NC}"
else
    echo -e "${YELLOW}Firewall not found, skipping${NC}"
fi
echo ""

# Summary
echo "================================================"
echo "  Installation Summary"
echo "================================================"
echo ""

echo -e "${YELLOW}Checking installed components:${NC}"
echo ""

# Refresh PATH before checking
export PATH="/usr/local/bin:/usr/bin:/bin:/root/.dotnet/tools:/opt/mssql-tools/bin:$PATH"
if [ "$K8S_TYPE" == "k3s" ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# Detect if this is a GUI machine (graphical target) or headless
GUI_AVAILABLE=false
if command -v systemctl &> /dev/null; then
    if systemctl get-default 2>/dev/null | grep -q "graphical.target"; then
        GUI_AVAILABLE=true
    fi
fi

# Detect if Kubernetes Dashboard is installed
DASHBOARD_INSTALLED=false
if command -v kubectl &> /dev/null && kubectl get namespace kubernetes-dashboard &> /dev/null; then
    DASHBOARD_INSTALLED=true
fi

if command -v kubectl &> /dev/null || [ -f /usr/local/bin/kubectl ]; then
    echo -e "${GREEN}[OK] kubectl${NC}"
else
    echo -e "${RED}[!!] kubectl${NC}"
fi

if command -v k9s &> /dev/null || [ -f /usr/local/bin/k9s ]; then
    echo -e "${GREEN}[OK] k9s${NC}"
else
    echo -e "${RED}[!!] k9s${NC}"
fi

if [ "$K8S_TYPE" == "k3s" ]; then
    if command -v k3s &> /dev/null; then
        echo -e "${GREEN}[OK] k3s (Kubernetes cluster)${NC}"
    else
        echo -e "${RED}[!!] k3s${NC}"
    fi
else
    if command -v minikube &> /dev/null; then
        echo -e "${GREEN}[OK] minikube (Kubernetes cluster)${NC}"
    else
        echo -e "${RED}[!!] minikube${NC}"
    fi
fi

# Dashboard status summary respects headless mode
if [ "$DASHBOARD_INSTALLED" = "true" ]; then
    echo -e "${GREEN}[OK] Kubernetes Dashboard${NC}"
else
    if [ "$GUI_AVAILABLE" = "true" ]; then
        echo -e "${RED}[!!] Kubernetes Dashboard (not installed)${NC}"
    else
        echo -e "${GRAY}[--] Kubernetes Dashboard (skipped on headless server)${NC}"
    fi
fi

# Lens summary also respects headless mode
if [ -f "/usr/local/bin/lens" ]; then
    echo -e "${GREEN}[OK] Lens${NC}"
else
    if [ "$GUI_AVAILABLE" = "true" ]; then
        echo -e "${GRAY}[--] Lens (not installed)${NC}"
    else
        echo -e "${GRAY}[--] Lens (skipped on headless server)${NC}"
    fi
fi

if command -v dotnet &> /dev/null; then
    echo -e "${GREEN}[OK] .NET SDK${NC}"
else
    echo -e "${RED}[!!] .NET SDK${NC}"
fi

if dotnet tool list -g 2>/dev/null | grep -q aspirate; then
    echo -e "${GREEN}[OK] Aspirate${NC}"
else
    echo -e "${YELLOW}[!!] Aspirate (restart terminal)${NC}"
fi

if command -v sqlcmd &> /dev/null || [ -f /opt/mssql-tools/bin/sqlcmd ]; then
    echo -e "${GREEN}[OK] mssql-tools (sqlcmd, bcp)${NC}"
else
    echo -e "${RED}[!!] mssql-tools${NC}"
fi

echo ""
echo "================================================"
echo "  Verifying Kubernetes Cluster"
echo "================================================"
echo ""

# Verify cluster is running
if command -v kubectl &> /dev/null; then
    echo -e "${CYAN}Checking cluster status...${NC}"
    sleep 5
    
    if kubectl get nodes 2>/dev/null; then
        echo ""
        echo -e "${GREEN}Kubernetes cluster is ready!${NC}"
    else
        echo -e "${YELLOW}Cluster may still be initializing...${NC}"
        echo -e "${GRAY}Wait a moment and run: kubectl get nodes${NC}"
    fi
else
    echo -e "${YELLOW}kubectl not available${NC}"
fi

echo ""
echo "================================================"
echo "  Kubernetes Dashboard Access"
echo "================================================"
echo ""

if [ "$DASHBOARD_INSTALLED" = "true" ] && [ -f /root/k8s-dashboard-token.txt ]; then
    if [ "$K8S_TYPE" == "k3s" ]; then
        echo -e "${YELLOW}Dashboard URL:${NC}"
        echo -e "  ${CYAN}https://localhost:30443${NC}"
        echo ""
        echo -e "${YELLOW}Access Token (saved in k8s-dashboard-token.txt):${NC}"
        echo -e "  ${GRAY}$(head -c 60 /root/k8s-dashboard-token.txt)...${NC}"
        echo ""
        echo -e "${YELLOW}To access the dashboard:${NC}"
        echo -e "  1. Open: ${CYAN}https://localhost:30443${NC}"
        echo -e "  2. Select 'Token' authentication"
        echo -e "  3. Paste token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
        echo ""
        echo -e "${GRAY}Note: Accept the self-signed certificate warning${NC}"
    else
        echo -e "${YELLOW}Dashboard Access Options:${NC}"
        echo ""
        echo -e "${CYAN}Option 1: Use minikube dashboard command:${NC}"
        echo -e "  ${GRAY}minikube dashboard${NC}"
        echo ""
        echo -e "${CYAN}Option 2: Use kubectl port-forward:${NC}"
        echo -e "  ${GRAY}kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443${NC}"
        echo -e "  Then access: ${GRAY}https://localhost:8443${NC}"
        echo ""
        echo -e "${YELLOW}Access Token (saved in k8s-dashboard-token.txt):${NC}"
        echo -e "  ${GRAY}$(head -c 60 /root/k8s-dashboard-token.txt)...${NC}"
        echo -e "  Use token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
    fi
else
    echo -e "${GRAY}Kubernetes Dashboard is not configured on this machine.${NC}"
    if [ "$GUI_AVAILABLE" != "true" ]; then
        echo -e "${GRAY}It was skipped because this appears to be a headless server (no graphical target).${NC}"
    else
        echo -e "${GRAY}You can install it later if you need a web UI for your cluster.${NC}"
    fi
fi

echo ""
echo "================================================"
echo "  Next Steps"
echo "================================================"
echo ""

echo -e "${YELLOW}1. Restart your terminal or run:${NC}"
echo -e "   ${CYAN}source ~/.bashrc${NC}"
echo ""

echo -e "${YELLOW}2. Verify Kubernetes cluster:${NC}"
echo -e "   ${CYAN}kubectl get nodes${NC}"
echo -e "   ${CYAN}kubectl get pods -A${NC}"
echo ""

echo -e "${YELLOW}3. Access Kubernetes Dashboard:${NC}"
if [ "$DASHBOARD_INSTALLED" = "true" ]; then
    if [ "$K8S_TYPE" == "k3s" ]; then
        echo -e "   ${CYAN}https://localhost:30443${NC}"
    else
        echo -e "   ${CYAN}minikube dashboard${NC} or"
        echo -e "   ${CYAN}kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443${NC}"
    fi
    echo -e "   Use token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
else
    if [ "$GUI_AVAILABLE" = "true" ]; then
        echo -e "   ${GRAY}(Dashboard is not installed. You can install it later if you need a GUI.)${NC}"
    else
        echo -e "   ${GRAY}(Skipped: no GUI detected; dashboard is optional on headless servers.)${NC}"
    fi
fi
echo ""

echo -e "${YELLOW}4. Use k9s to manage your cluster:${NC}"
echo -e "   ${CYAN}k9s${NC}"
echo ""

if [ -f "/usr/local/bin/lens" ]; then
    echo -e "${YELLOW}5. Launch Lens from applications menu${NC}"
    echo ""
fi

echo -e "${YELLOW}6. Deploy your application with Aspirate:${NC}"
echo -e "   ${CYAN}aspirate --version${NC}"
echo ""

echo -e "${YELLOW}7. Connect to SQL Server databases:${NC}"
echo -e "   ${CYAN}sqlcmd -S <server> -U <username> -P <password>${NC}"
echo -e "   ${CYAN}bcp <table> in <datafile> -S <server> -U <username> -P <password>${NC}"
echo ""

if [ "$K8S_TYPE" == "minikube" ]; then
    echo -e "${YELLOW}Minikube specific commands:${NC}"
    echo -e "   ${CYAN}minikube status${NC} - Check cluster status"
    echo -e "   ${CYAN}minikube stop${NC} - Stop the cluster"
    echo -e "   ${CYAN}minikube start${NC} - Start the cluster"
    echo -e "   ${CYAN}minikube delete${NC} - Delete the cluster"
    echo -e "   ${CYAN}minikube service <service-name>${NC} - Access a service"
    echo ""
fi

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}Your Kubernetes environment is ready!${NC}"
