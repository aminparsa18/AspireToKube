#!/bin/bash

# Prerequisites Installation Script for Ubuntu - Minikube Edition
# Installation: Update System -> firewalld -> Docker -> Minikube -> kubectl -> k9s -> Dashboard -> Lens -> jq -> Python3/cryptography

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

echo "================================================"
echo "  Installing Kubernetes Prerequisites (Minikube)"
echo "================================================"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# [1/9] Update system
echo -e "${YELLOW}[1/9] Updating system...${NC}"
apt-get update -y
apt-get upgrade -y
echo -e "${GREEN}System updated${NC}"
echo ""

# [2/9] Install firewalld
echo -e "${YELLOW}[2/9] Installing firewalld...${NC}"
if command -v firewall-cmd &> /dev/null; then
    echo -e "${GREEN}firewalld already installed${NC}"
    firewall-cmd --version 2>/dev/null || true
else
    echo -e "${CYAN}Installing firewalld...${NC}"
    apt-get install -y firewalld
    
    # Start and enable firewalld
    systemctl start firewalld
    systemctl enable firewalld
    
    echo -e "${GREEN}firewalld installed and started${NC}"
fi
echo ""

# [3/9] Install Docker (required for Minikube)
echo -e "${YELLOW}[3/9] Installing Docker...${NC}"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker already installed${NC}"
    docker --version
else
    echo -e "${CYAN}Installing Docker...${NC}"
    
    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add user to docker group if running with sudo
    if [ "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        echo -e "${CYAN}Added $SUDO_USER to docker group${NC}"
    fi
    
    echo -e "${GREEN}Docker installed successfully${NC}"
    docker --version
fi
echo ""

# [4/9] Install Minikube
echo -e "${YELLOW}[4/9] Installing Minikube (Kubernetes cluster)...${NC}"

if command -v minikube &> /dev/null; then
    echo -e "${GREEN}Minikube already installed${NC}"
    minikube version
else
    echo -e "${CYAN}Downloading Minikube...${NC}"
    
    # Download latest stable Minikube binary
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install minikube-linux-amd64 /usr/local/bin/minikube
    rm -f minikube-linux-amd64
    
    echo -e "${GREEN}Minikube installed successfully${NC}"
    minikube version
fi

# Start Minikube if not already running
if minikube status &> /dev/null; then
    echo -e "${GREEN}Minikube is already running${NC}"
    minikube status
else
    echo -e "${CYAN}Starting Minikube cluster...${NC}"
    
    # Determine if running as root or with sudo
    if [ "$SUDO_USER" ]; then
        # Running with sudo - start as the actual user
        SUDO_HOME=$(eval echo ~$SUDO_USER)
        echo -e "${CYAN}Starting Minikube as user $SUDO_USER...${NC}"
        
        # Start Minikube with docker driver as the sudo user
        su - $SUDO_USER -c "minikube start --driver=docker --cpus=2 --memory=4096 --addons=dashboard --addons=ingress"
    else
        # Running as root - need to use --force flag
        echo -e "${YELLOW}Warning: Running Minikube as root (not recommended)${NC}"
        minikube start --driver=docker --cpus=2 --memory=4096 --addons=dashboard --addons=ingress --force
    fi
    
    echo -e "${GREEN}Minikube cluster started successfully${NC}"
fi
echo ""

# [5/9] Install kubectl
echo -e "${YELLOW}[5/9] Installing kubectl...${NC}"

if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}kubectl already installed${NC}"
    kubectl version --client
else
    echo -e "${CYAN}Downloading kubectl...${NC}"
    
    # Download latest stable kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    
    echo -e "${GREEN}kubectl installed successfully${NC}"
    kubectl version --client
fi

# Configure kubectl for Minikube
if [ "$SUDO_USER" ]; then
    SUDO_HOME=$(eval echo ~$SUDO_USER)
    echo -e "${CYAN}Configuring kubectl for user $SUDO_USER...${NC}"
    
    # Ensure .kube directory exists
    su - $SUDO_USER -c "mkdir -p ~/.kube"
    
    # Copy Minikube config
    su - $SUDO_USER -c "minikube kubectl -- config view --raw > ~/.kube/config"
    su - $SUDO_USER -c "chmod 600 ~/.kube/config"
fi

# Also configure for root
mkdir -p /root/.kube
if [ "$SUDO_USER" ]; then
    SUDO_HOME=$(eval echo ~$SUDO_USER)
    cp "$SUDO_HOME/.kube/config" /root/.kube/config 2>/dev/null || \
        minikube kubectl -- config view --raw > /root/.kube/config
else
    minikube kubectl -- config view --raw > /root/.kube/config
fi
chmod 600 /root/.kube/config

echo ""

# Configure firewall for Minikube
if systemctl is-active --quiet firewalld; then
    echo -e "${CYAN}Configuring firewall rules for Minikube...${NC}"
    
    # Minikube API server (proxied through minikube)
    firewall-cmd --permanent --add-port=8443/tcp    # Minikube API server
    
    # Common service ports
    firewall-cmd --permanent --add-port=80/tcp      # HTTP
    firewall-cmd --permanent --add-port=443/tcp     # HTTPS
    firewall-cmd --permanent --add-port=8080/tcp    # Common app port
    firewall-cmd --permanent --add-port=1433/tcp    # SQL Server
    
    # Dashboard
    firewall-cmd --permanent --add-port=30443/tcp   # Dashboard NodePort
    firewall-cmd --permanent --add-port=8001/tcp    # kubectl proxy
    
    # NodePort range
    firewall-cmd --permanent --add-port=30000-32767/tcp  # Kubernetes NodePort range
    
    # Docker (if needed for remote access)
    firewall-cmd --permanent --add-port=2375/tcp    # Docker daemon
    firewall-cmd --permanent --add-port=2376/tcp    # Docker daemon (TLS)
    
    # Reload firewall
    firewall-cmd --reload
    
    echo -e "${GREEN}Firewall configured for Minikube${NC}"
else
    echo -e "${YELLOW}firewalld is not active${NC}"
fi
echo ""

# [6/9] Install k9s
echo -e "${YELLOW}[6/9] Installing k9s...${NC}"

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

# [7/9] Configure Kubernetes Dashboard
echo -e "${YELLOW}[7/9] Configuring Kubernetes Dashboard...${NC}"

# Dashboard is already enabled via minikube addons
if kubectl get namespace kubernetes-dashboard &> /dev/null; then
    echo -e "${GREEN}Kubernetes Dashboard already configured${NC}"
else
    echo -e "${CYAN}Enabling Kubernetes Dashboard addon...${NC}"
    
    if [ "$SUDO_USER" ]; then
        su - $SUDO_USER -c "minikube addons enable dashboard"
    else
        minikube addons enable dashboard --force
    fi
fi

# Wait for dashboard to be ready
echo -e "${CYAN}Waiting for dashboard pods to be ready...${NC}"
sleep 10
kubectl wait --for=condition=ready pod -l k8s-app=kubernetes-dashboard -n kubernetes-dashboard --timeout=120s 2>/dev/null || true

# Create service account for dashboard access
echo -e "${CYAN}Creating dashboard service account...${NC}"

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

# Get access token
echo -e "${CYAN}Generating access token...${NC}"
sleep 5

# Create token and save it
kubectl -n kubernetes-dashboard create token admin-user --duration=87600h > /root/k8s-dashboard-token.txt 2>/dev/null || \
    kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}" > /root/k8s-dashboard-token.txt 2>/dev/null || \
    echo "Failed to get token" > /root/k8s-dashboard-token.txt

chmod 600 /root/k8s-dashboard-token.txt

# Also save for sudo user if exists
if [ "$SUDO_USER" ]; then
    SUDO_HOME=$(eval echo ~$SUDO_USER)
    cp /root/k8s-dashboard-token.txt "$SUDO_HOME/k8s-dashboard-token.txt"
    chown $SUDO_USER:$SUDO_USER "$SUDO_HOME/k8s-dashboard-token.txt"
    chmod 600 "$SUDO_HOME/k8s-dashboard-token.txt"
fi

# Expose dashboard as NodePort for easier access
echo -e "${CYAN}Exposing dashboard via NodePort...${NC}"
kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8443,"nodePort":30443}]}}' 2>/dev/null || true

echo -e "${GREEN}Kubernetes Dashboard configured successfully${NC}"
echo ""

# [8/9] Lens installation (optional)
echo -e "${YELLOW}[8/9] Lens installation (Kubernetes IDE - optional)...${NC}"

# Only makes sense on machines with a graphical desktop
LENS_GUI_AVAILABLE=false

# Check for graphical environment
if command -v systemctl &> /dev/null; then
    if systemctl get-default 2>/dev/null | grep -q "graphical.target"; then
        LENS_GUI_AVAILABLE=true
    fi
fi

# Additional check for DISPLAY variable (X11/Wayland)
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    LENS_GUI_AVAILABLE=true
fi

if [ "$LENS_GUI_AVAILABLE" != "true" ]; then
    echo -e "${GRAY}No graphical desktop detected.${NC}"
    echo -e "${GRAY}Skipping Lens installation (Lens requires a GUI desktop environment).${NC}"
else
    # Add timeout in case script is run non-interactively
    read -t 30 -p "Do you want to install Lens? (y/n): " INSTALL_LENS || INSTALL_LENS="n"
    echo ""

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

# [9/9] Install jq and Python3
echo -e "${YELLOW}[9/9] Installing jq and Python3 with cryptography...${NC}"

# Install jq (JSON processor)
if command -v jq &> /dev/null; then
    echo -e "${GREEN}jq already installed: $(jq --version)${NC}"
else
    apt-get install -y jq
    echo -e "${GREEN}jq installed successfully${NC}"
fi

# Install Python3 and pip
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}Python3 already installed: $(python3 --version)${NC}"
else
    apt-get install -y python3 python3-pip python3-venv
    echo -e "${GREEN}Python3 installed successfully${NC}"
fi

if command -v pip3 &> /dev/null; then
    echo -e "${GREEN}pip3 already installed: $(pip3 --version)${NC}"
else
    apt-get install -y python3-pip
    echo -e "${GREEN}pip3 installed successfully${NC}"
fi

# Install Python cryptography library
if python3 -c "import cryptography" 2>/dev/null; then
    echo -e "${GREEN}cryptography library already installed${NC}"
    python3 -c "import cryptography; print(f'Version: {cryptography.__version__}')"
else
    pip3 install --break-system-packages cryptography
    echo -e "${GREEN}cryptography library installed successfully${NC}"
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
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Check all components in installation order
if command -v firewall-cmd &> /dev/null; then
    echo -e "${GREEN}[OK] firewalld${NC}"
    if systemctl is-active --quiet firewalld; then
        echo -e "${GREEN}    └─ Status: Active${NC}"
    else
        echo -e "${YELLOW}    └─ Status: Inactive${NC}"
    fi
else
    echo -e "${RED}[!!] firewalld${NC}"
fi

if command -v docker &> /dev/null; then
    echo -e "${GREEN}[OK] Docker${NC}"
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}    └─ Status: Active${NC}"
    else
        echo -e "${YELLOW}    └─ Status: Inactive${NC}"
    fi
else
    echo -e "${RED}[!!] Docker${NC}"
fi

if command -v minikube &> /dev/null; then
    echo -e "${GREEN}[OK] Minikube${NC}"
    if minikube status &> /dev/null; then
        echo -e "${GREEN}    └─ Status: Running${NC}"
    else
        echo -e "${YELLOW}    └─ Status: Not running${NC}"
    fi
else
    echo -e "${RED}[!!] Minikube${NC}"
fi

if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}[OK] kubectl${NC}"
else
    echo -e "${RED}[!!] kubectl${NC}"
fi

if command -v k9s &> /dev/null; then
    echo -e "${GREEN}[OK] k9s${NC}"
else
    echo -e "${RED}[!!] k9s${NC}"
fi

if kubectl get namespace kubernetes-dashboard &> /dev/null; then
    echo -e "${GREEN}[OK] Kubernetes Dashboard${NC}"
else
    echo -e "${RED}[!!] Kubernetes Dashboard${NC}"
fi

if [ -f "/usr/local/bin/lens" ]; then
    echo -e "${GREEN}[OK] Lens${NC}"
else
    if [ "$LENS_GUI_AVAILABLE" = "true" ]; then
        echo -e "${GRAY}[--] Lens (not installed)${NC}"
    else
        echo -e "${GRAY}[--] Lens (skipped on headless server)${NC}"
    fi
fi

if command -v jq &> /dev/null; then
    echo -e "${GREEN}[OK] jq${NC}"
else
    echo -e "${RED}[!!] jq${NC}"
fi

if command -v python3 &> /dev/null; then
    echo -e "${GREEN}[OK] Python3${NC}"
else
    echo -e "${RED}[!!] Python3${NC}"
fi

if python3 -c "import cryptography" 2>/dev/null; then
    echo -e "${GREEN}[OK] cryptography library${NC}"
else
    echo -e "${RED}[!!] cryptography library${NC}"
fi

echo ""
echo "================================================"
echo "  Verifying Kubernetes Cluster"
echo "================================================"
echo ""

# Verify cluster is running
if command -v kubectl &> /dev/null; then
    echo -e "${CYAN}Checking cluster status...${NC}"
    sleep 3
    
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
echo "  Firewall Status"
echo "================================================"
echo ""

if systemctl is-active --quiet firewalld; then
    echo -e "${GREEN}Firewall is active${NC}"
    echo ""
    echo -e "${CYAN}Open ports:${NC}"
    firewall-cmd --list-ports | tr ' ' '\n' | sort
    echo ""
    echo -e "${CYAN}Active services:${NC}"
    firewall-cmd --list-services
else
    echo -e "${YELLOW}Firewall is not active${NC}"
fi

echo ""
echo "================================================"
echo "  Kubernetes Dashboard Access"
echo "================================================"
echo ""

if kubectl get namespace kubernetes-dashboard &> /dev/null && [ -f /root/k8s-dashboard-token.txt ]; then
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${YELLOW}Dashboard URLs:${NC}"
    echo -e "  ${CYAN}Method 1 - Minikube service (recommended):${NC}"
    echo -e "    Run: ${GRAY}minikube dashboard${NC}"
    echo -e "    This will automatically open the dashboard in your browser"
    echo ""
    echo -e "  ${CYAN}Method 2 - NodePort (remote access):${NC}"
    echo -e "    ${CYAN}https://${MINIKUBE_IP}:30443${NC}"
    echo ""
    echo -e "  ${CYAN}Method 3 - kubectl proxy:${NC}"
    echo -e "    Run: ${GRAY}kubectl proxy${NC}"
    echo -e "    Then open: ${CYAN}http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/${NC}"
    echo ""
    echo -e "${YELLOW}Access Token (saved in k8s-dashboard-token.txt):${NC}"
    if [ -s /root/k8s-dashboard-token.txt ]; then
        echo -e "  ${GRAY}$(head -c 60 /root/k8s-dashboard-token.txt)...${NC}"
    else
        echo -e "  ${RED}Token file is empty or missing${NC}"
    fi
    echo ""
    echo -e "${YELLOW}To access with token:${NC}"
    echo -e "  1. Use one of the methods above to open the dashboard"
    echo -e "  2. Select 'Token' authentication"
    echo -e "  3. Paste token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
    echo ""
    echo -e "${GRAY}Note: Accept the self-signed certificate warning if prompted${NC}"
else
    echo -e "${YELLOW}Kubernetes Dashboard installation failed or is incomplete.${NC}"
    echo -e "${GRAY}Check the installation logs above for errors.${NC}"
fi

echo ""
echo "================================================"
echo "  Aspire Secret Decryption Ready"
echo "================================================"
echo ""

echo -e "${GREEN}All dependencies for Aspire secret decryption are installed:${NC}"
echo -e "  ✓ jq - for parsing aspirate-state.json"
echo -e "  ✓ Python3 - for running decrypt-secrets.py"
echo -e "  ✓ cryptography - for AES-GCM decryption"
echo ""
echo -e "${YELLOW}You can now decrypt your Aspire secrets:${NC}"
echo -e "  ${CYAN}./decrypt-secrets.py${NC}"
echo ""

echo ""
echo "================================================"
echo "  Next Steps"
echo "================================================"
echo ""

echo -e "${YELLOW}1. If you were added to the docker group, log out and back in:${NC}"
echo -e "   ${CYAN}exit${NC} (then reconnect)"
echo -e "   Or run: ${CYAN}newgrp docker${NC}"
echo ""

echo -e "${YELLOW}2. Verify Minikube cluster:${NC}"
echo -e "   ${CYAN}minikube status${NC}"
echo -e "   ${CYAN}kubectl get nodes${NC}"
echo -e "   ${CYAN}kubectl get pods -A${NC}"
echo ""

echo -e "${YELLOW}3. Access Kubernetes Dashboard:${NC}"
echo -e "   ${CYAN}minikube dashboard${NC} (easiest method)"
echo -e "   Or use token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
echo ""

echo -e "${YELLOW}4. Use k9s to manage your cluster:${NC}"
echo -e "   ${CYAN}k9s${NC}"
echo ""

if [ -f "/usr/local/bin/lens" ]; then
    echo -e "${YELLOW}5. Launch Lens from applications menu${NC}"
    echo "   Connect to Minikube context"
    echo ""
fi

echo -e "${YELLOW}6. Useful Minikube commands:${NC}"
echo -e "   ${CYAN}minikube start${NC}      - Start the cluster"
echo -e "   ${CYAN}minikube stop${NC}       - Stop the cluster"
echo -e "   ${CYAN}minikube delete${NC}     - Delete the cluster"
echo -e "   ${CYAN}minikube ssh${NC}        - SSH into the Minikube VM"
echo -e "   ${CYAN}minikube service <name>${NC} - Get URL for a service"
echo -e "   ${CYAN}minikube addons list${NC} - List available addons"
echo ""

echo -e "${YELLOW}7. Deploy your Aspire application:${NC}"
echo -e "   ${CYAN}# Decrypt secrets first:${NC}"
echo -e "   ${CYAN}./decrypt-secrets.py${NC}"
echo -e "   ${CYAN}# Then deploy:${NC}"
echo -e "   ${CYAN}./deploy2k3s.sh${NC} (may need modifications for Minikube)"
echo ""

echo -e "${YELLOW}8. Access services in Minikube:${NC}"
echo -e "   ${CYAN}minikube service <service-name>${NC}"
echo -e "   Or use port-forward: ${CYAN}kubectl port-forward svc/<service-name> <local-port>:<service-port>${NC}"
echo ""

echo -e "${YELLOW}9. Connect to SQL Server in Kubernetes:${NC}"
echo -e "   ${CYAN}kubectl exec -it <sql-pod-name> -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '<password>'${NC}"
echo -e "   Or use port-forward: ${CYAN}kubectl port-forward svc/<sql-service> 1433:1433${NC}"
echo ""

echo -e "${YELLOW}10. Check firewall status:${NC}"
echo -e "   ${CYAN}firewall-cmd --list-all${NC}"
echo ""

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}Your Minikube environment is ready for Aspire deployments!${NC}"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo -e "  • Minikube runs in a VM/container, so service access differs from k3s"
echo -e "  • Use 'minikube service' or 'kubectl port-forward' to access services"
echo -e "  • Minikube IP: ${CYAN}$(minikube ip 2>/dev/null || echo 'not running')${NC}"
echo -e "  • Default resources: 2 CPUs, 4096 MB RAM (adjust with minikube start flags)"
