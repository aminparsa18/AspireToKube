#!/bin/bash

# Prerequisites Installation Script for Ubuntu
# Installs: k9s, k3s OR minikube, Kubernetes Dashboard, Lens (optional)
# Note: kubectl is included with both k3s and minikube

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
echo -e "${YELLOW}[1/6] Updating system...${NC}"
apt-get update -y
apt-get upgrade -y
echo -e "${GREEN}System updated${NC}"
echo ""

# Choose Kubernetes implementation
echo -e "${YELLOW}[2/6] Choose Kubernetes implementation:${NC}"
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

# Install k9s
echo -e "${YELLOW}[3/7] Installing k9s...${NC}"

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
echo -e "${YELLOW}[4/7] Installing $K8S_TYPE (Kubernetes cluster)...${NC}"

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
        apt-get install -y conntrack socat
        
        # Check if running in a VM or physical machine
        if systemctl is-active --quiet libvirtd || grep -E '(vmx|svm)' /proc/cpuinfo > /dev/null; then
            echo -e "${CYAN}Installing KVM/libvirt for minikube (VM driver)...${NC}"
            apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager
            systemctl start libvirtd
            systemctl enable libvirtd
            
            # Add user to libvirt group
            if [ "$SUDO_USER" ]; then
                usermod -aG libvirt $SUDO_USER
            fi
            
            MINIKUBE_DRIVER="kvm2"
        else
            echo -e "${YELLOW}No virtualization detected, will use Docker driver${NC}"
            # Install Docker
            echo -e "${CYAN}Installing Docker for minikube...${NC}"
            
            # Remove old Docker packages if they exist
            apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Install Docker prerequisites
            apt-get install -y ca-certificates curl gnupg lsb-release
            
            # Add Docker GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Add Docker repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            # Start and enable Docker
            systemctl start docker
            systemctl enable docker
            
            # Add user to docker group
            if [ "$SUDO_USER" ]; then
                usermod -aG docker $SUDO_USER
            fi
            
            MINIKUBE_DRIVER="docker"
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
                # minikube doesn't like running as root with docker unless you use --force
                if [ "$(id -u)" -eq 0 ] && [ "$MINIKUBE_DRIVER" = "docker" ]; then
                    minikube start --driver="$MINIKUBE_DRIVER" --force
                else
                    minikube start --driver="$MINIKUBE_DRIVER"
                fi
                
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
echo -e "${YELLOW}[5/7] Installing Kubernetes Dashboard...${NC}"

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
echo ""

# Lens installation (optional)
echo -e "${YELLOW}[6/7] Lens installation (Kubernetes IDE)...${NC}"

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

# Configure firewall (UFW on Ubuntu)
echo -e "${YELLOW}[7/7] Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    # Check if UFW is active
    if ufw status | grep -q "Status: active"; then
        ufw allow 30000:32767/tcp 2>/dev/null || true
        ufw allow 6443/tcp 2>/dev/null || true
        ufw allow 80/tcp 2>/dev/null || true
        ufw allow 443/tcp 2>/dev/null || true
        ufw allow 8080/tcp 2>/dev/null || true
        ufw allow 30443/tcp 2>/dev/null || true  # Dashboard
        ufw allow 8443/tcp 2>/dev/null || true   # Dashboard port-forward
        ufw reload 2>/dev/null || true
        echo -e "${GREEN}Firewall configured${NC}"
    else
        echo -e "${YELLOW}UFW is not active, skipping firewall configuration${NC}"
    fi
else
    echo -e "${YELLOW}UFW not found, skipping firewall configuration${NC}"
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

# Dashboard status - now installed on all systems
if [ "$DASHBOARD_INSTALLED" = "true" ]; then
    echo -e "${GREEN}[OK] Kubernetes Dashboard${NC}"
else
    echo -e "${RED}[!!] Kubernetes Dashboard (not installed)${NC}"
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
        echo -e "${YELLOW}Dashboard URL (NodePort - accessible remotely):${NC}"
        echo -e "  ${CYAN}https://<server-ip>:30443${NC}"
        echo -e "  ${CYAN}https://localhost:30443${NC} (if accessing from this server)"
        echo ""
        echo -e "${YELLOW}Access Token (saved in k8s-dashboard-token.txt):${NC}"
        echo -e "  ${GRAY}$(head -c 60 /root/k8s-dashboard-token.txt)...${NC}"
        echo ""
        echo -e "${YELLOW}To access the dashboard:${NC}"
        echo -e "  ${CYAN}Locally:${NC}"
        echo -e "    1. Open: ${CYAN}https://localhost:30443${NC}"
        echo -e "    2. Select 'Token' authentication"
        echo -e "    3. Paste token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
        echo ""
        echo -e "  ${CYAN}Remotely (from another machine):${NC}"
        echo -e "    1. Open: ${CYAN}https://<server-ip>:30443${NC}"
        echo -e "    2. Select 'Token' authentication"
        echo -e "    3. Use token from the server"
        echo ""
        echo -e "  ${CYAN}Via SSH Tunnel (more secure):${NC}"
        echo -e "    1. Run on your local machine: ${GRAY}ssh -L 8443:localhost:30443 user@server-ip${NC}"
        echo -e "    2. Open: ${CYAN}https://localhost:8443${NC}"
        echo -e "    3. Use the token"
        echo ""
        echo -e "${GRAY}Note: Accept the self-signed certificate warning${NC}"
    else
        echo -e "${YELLOW}Dashboard Access Options:${NC}"
        echo ""
        echo -e "${CYAN}Option 1: Use minikube dashboard command (local only):${NC}"
        echo -e "  ${GRAY}minikube dashboard${NC}"
        echo ""
        echo -e "${CYAN}Option 2: kubectl port-forward (local):${NC}"
        echo -e "  ${GRAY}kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443${NC}"
        echo -e "  Then access: ${GRAY}https://localhost:8443${NC}"
        echo ""
        echo -e "${CYAN}Option 3: SSH Tunnel for remote access:${NC}"
        echo -e "  On server: ${GRAY}kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443${NC}"
        echo -e "  On local machine: ${GRAY}ssh -L 8443:localhost:8443 user@server-ip${NC}"
        echo -e "  Then access: ${GRAY}https://localhost:8443${NC}"
        echo ""
        echo -e "${YELLOW}Access Token (saved in k8s-dashboard-token.txt):${NC}"
        echo -e "  ${GRAY}$(head -c 60 /root/k8s-dashboard-token.txt)...${NC}"
        echo -e "  Use token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
    fi
else
    echo -e "${YELLOW}Kubernetes Dashboard installation failed or is incomplete.${NC}"
    echo -e "${GRAY}Check the installation logs above for errors.${NC}"
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
        echo -e "   ${CYAN}https://<server-ip>:30443${NC} or ${CYAN}https://localhost:30443${NC}"
    else
        echo -e "   ${CYAN}minikube dashboard${NC} or"
        echo -e "   ${CYAN}kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443${NC}"
    fi
    echo -e "   Use token from: ${CYAN}cat ~/k8s-dashboard-token.txt${NC}"
    echo -e "   See 'Kubernetes Dashboard Access' section above for remote access options"
else
    echo -e "   ${GRAY}Dashboard installation may have failed. Check logs above.${NC}"
fi
echo ""

echo -e "${YELLOW}4. Use k9s to manage your cluster:${NC}"
echo -e "   ${CYAN}k9s${NC}"
echo ""

if [ -f "/usr/local/bin/lens" ]; then
    echo -e "${YELLOW}5. Launch Lens from applications menu${NC}"
    echo ""
fi

echo -e "${YELLOW}6. Connect to SQL Server in Kubernetes:${NC}"
echo -e "   ${CYAN}kubectl exec -it <sql-pod-name> -n <namespace> -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '<password>'${NC}"
echo -e "   Or use port-forward: ${CYAN}kubectl port-forward svc/<sql-service> 1433:1433${NC}"
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