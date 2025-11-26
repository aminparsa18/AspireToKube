#!/bin/bash

# Generic Aspire / Minikube deployment script
# Run from directory that contains:
#   - manifests/
#   - *.tar (custom images)
#   - optional top-level kustomization.yaml (applied last)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "================================================"
echo "  ECS Application Deployment (Minikube)"
echo "================================================"
echo ""

# ================================================
# STEP 0: Check if running as root/sudo
# ================================================

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run with sudo${NC}"
    echo ""
    echo "Please run:"
    echo -e "  ${CYAN}sudo bash $0${NC}"
    echo ""
    exit 1
fi

BASE_DIR="$(pwd)"
MANIFESTS_DIR="${BASE_DIR}/manifests"

if [ ! -d "$MANIFESTS_DIR" ]; then
    echo -e "${RED}manifests/ folder not found in current directory.${NC}"
    echo "Run this script from the directory containing your manifests folder."
    exit 1
fi

# ================================================
# STEP 1: Check Minikube installation
# ================================================

if ! command -v minikube &>/dev/null; then
    echo -e "${RED}minikube not found in PATH.${NC}"
    echo ""
    echo "To install Minikube, run:"
    echo -e "  ${CYAN}curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64${NC}"
    echo -e "  ${CYAN}sudo install minikube-linux-amd64 /usr/local/bin/minikube${NC}"
    echo ""
    exit 1
fi

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}kubectl not found in PATH.${NC}"
    echo ""
    echo "To install kubectl, run:"
    echo -e "  ${CYAN}sudo apt-get update && sudo apt-get install -y kubectl${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Minikube and kubectl found${NC}"
echo ""

# ================================================
# STEP 2: Check Minikube status
# ================================================

echo -e "${YELLOW}Checking Minikube status...${NC}"

if ! minikube status &>/dev/null; then
    echo -e "${YELLOW}Minikube is not running. Starting Minikube...${NC}"
    minikube start --driver=docker
    echo -e "${GREEN}✓ Minikube started${NC}"
else
    echo -e "${GREEN}✓ Minikube is already running${NC}"
fi

# Configure kubectl to use Minikube context
kubectl config use-context minikube
echo ""

# -------------------------------------------------------
# Helper: prepare secrets for a single kustomization dir
# -------------------------------------------------------
prepare_kustomization_secrets() {
    local svc_dir="$1"
    local svc_name
    svc_name="$(basename "$svc_dir")"

    local kfile=""
    if [ -f "$svc_dir/kustomization.yaml" ]; then
        kfile="$svc_dir/kustomization.yaml"
    elif [ -f "$svc_dir/kustomization.yml" ]; then
        kfile="$svc_dir/kustomization.yml"
    else
        return 0
    fi

    # Find envs: files under secretGenerator
    mapfile -t env_files_rel < <(
        awk '
        /secretGenerator:/ {inSG=1; next}
        /^[^[:space:]-]/ {inSG=0}
        inSG && /envs:/ {inEnv=1; next}
        inEnv {
            if ($1 == "-") {
                print $2
            } else if (NF == 0 || $1 ~ /^[a-zA-Z]/) {
                inEnv=0
            }
        }
        ' "$kfile" | sort -u
    )

    if [ "${#env_files_rel[@]}" -eq 0 ]; then
        return 0
    fi

    echo -e "${CYAN}Preparing secrets for '${svc_name}'...${NC}"

    local env_files_full=()
    for rel in "${env_files_rel[@]}"; do
        local full="${svc_dir}/${rel}"
        if [ ! -f "$full" ]; then
            echo -e "${YELLOW}  Creating missing secrets env file: ${full}${NC}"
            mkdir -p "$(dirname "$full")"
            : > "$full"
            chmod 600 "$full"
        fi
        env_files_full+=("$full")
    done

    # Find {placeholders} in the kustomization
    mapfile -t placeholders < <(
        grep -o '{[^}][^}]*}' "$kfile" 2>/dev/null \
        | tr -d '{}' \
        | sort -u
    )

    if [ "${#placeholders[@]}" -eq 0 ]; then
        return 0
    fi

    if ! [ -t 0 ]; then
        echo -e "${YELLOW}  Non-interactive shell; ensure secrets for placeholders exist in:${NC}"
        for f in "${env_files_full[@]}"; do
            echo "    - $f"
        done
        return 0
    fi

    echo
    echo -e "${CYAN}  >>> INPUT REQUIRED for '${svc_name}' secrets <<<${NC}"
    echo -e "${YELLOW}  For each one, enter a value and press ENTER (or just press ENTER to skip).${NC}"
    echo

    for ph in "${placeholders[@]}"; do
        local found=0
        for full in "${env_files_full[@]}"; do
            if grep -q "^${ph}=" "$full"; then
                found=1
                break
            fi
        done

        if [ "$found" -eq 1 ]; then
            continue
        fi

        echo
        echo -e "${YELLOW}  Missing secret value for '${ph}' in '${svc_name}'.${NC}"
        echo -e "${YELLOW}  It is referenced in ${kfile}.${NC}"
        read -s -p "  Enter value for ${ph} (or press ENTER to skip): " val
        echo
        if [ -z "$val" ]; then
            echo -e "${RED}  No value entered; skipping ${ph}. You can edit the secrets file manually later.${NC}"
            continue
        fi

        local target="${env_files_full[0]}"
        sed -i "/^${ph}=/d" "$target"
        echo "${ph}=${val}" >> "$target"
        chmod 600 "$target"
        echo -e "${GREEN}  Added '${ph}' to ${target}.${NC}"
    done
}

# -------------------------------------------------------
# STEP 3: Import all .tar images into Minikube
# -------------------------------------------------------
echo -e "${YELLOW}[1/3] Importing container images from *.tar into Minikube...${NC}"

# Point Docker to use Minikube's Docker daemon
eval $(minikube docker-env)

shopt -s nullglob
tar_files=("$BASE_DIR"/*.tar)
shopt -u nullglob

if [ "${#tar_files[@]}" -eq 0 ]; then
    echo -e "${YELLOW}No .tar files found, skipping image import.${NC}"
else
    for tar in "${tar_files[@]}"; do
        tar_name="$(basename "$tar")"
        echo -e "  Loading ${CYAN}${tar_name}${NC} into Minikube..."
        docker load -i "$tar"
    done
fi

echo -e "${GREEN}Image import phase finished.${NC}"
echo ""

# -------------------------------------------------------
# STEP 5: Deploy every kustomization under manifests/
# -------------------------------------------------------
echo -e "${YELLOW}[2/3] Applying manifests for all services...${NC}"

for dir in "$MANIFESTS_DIR"/*; do
    [ -d "$dir" ] || continue
    svc="$(basename "$dir")"

    if [ -f "$dir/kustomization.yaml" ] || [ -f "$dir/kustomization.yml" ]; then
        echo -e "${YELLOW}Deploying ${svc}...${NC}"

        # Prepare secrets for this top-level kustomization dir
        prepare_kustomization_secrets "$dir"

        # Also prepare secrets for any nested kustomizations
        while IFS= read -r -d '' kfile; do
            nested_dir="$(dirname "$kfile")"
            if [ "$nested_dir" != "$dir" ]; then
                prepare_kustomization_secrets "$nested_dir"
            fi
        done < <(find "$dir" -mindepth 2 -type f \( -name 'kustomization.yaml' -o -name 'kustomization.yml' \) -print0)

        kubectl apply -k "$dir"
        echo -e "${GREEN}${svc} deployed${NC}"
        echo ""
    fi
done

# -------------------------------------------------------
# OPTIONAL: root/parent kustomization (dashboard, etc.)
# Applied LAST if it exists
# -------------------------------------------------------
if [ -f "$BASE_DIR/kustomization.yaml" ] || [ -f "$BASE_DIR/kustomization.yml" ]; then
    echo -e "${YELLOW}Deploying top-level kustomization (parent folder)...${NC}"
    prepare_kustomization_secrets "$BASE_DIR"
    kubectl apply -k "$BASE_DIR"
    echo -e "${GREEN}Top-level kustomization deployed${NC}"
    echo ""
fi

# -------------------------------------------------------
# STEP 6: Status + URLs
# -------------------------------------------------------
echo "================================================"
echo "  Deployment Status"
echo "================================================"
echo ""

echo -e "${CYAN}Pods:${NC}"
kubectl get pods
echo ""

echo -e "${CYAN}Services:${NC}"
kubectl get services
echo ""

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

echo "================================================"
echo "  Access Information"
echo "================================================"
echo ""

echo -e "${YELLOW}Minikube IP: ${GREEN}${MINIKUBE_IP}${NC}"
echo ""

echo -e "${CYAN}Services with NodePort access:${NC}"
kubectl get services --all-namespaces -o wide | grep NodePort | while read -r line; do
    namespace=$(echo "$line" | awk '{print $1}')
    service=$(echo "$line" | awk '{print $2}')
    port=$(echo "$line" | awk '{print $5}' | grep -oP '\d+:\K\d+' | head -1)
    if [ ! -z "$port" ]; then
        echo -e "  ${service} (${namespace}): ${GREEN}http://${MINIKUBE_IP}:${port}${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View all pods:           ${CYAN}kubectl get pods${NC}"
echo -e "  View logs:               ${CYAN}kubectl logs <pod-name>${NC}"
echo -e "  Minikube dashboard:      ${CYAN}minikube dashboard${NC}"
echo -e "  Access a service:        ${CYAN}minikube service <service-name>${NC}"
echo -e "  Port forward:            ${CYAN}kubectl port-forward service/<name> 8080:8080${NC}"
echo -e "  Stop Minikube:           ${CYAN}minikube stop${NC}"
echo -e "  Delete Minikube cluster: ${CYAN}minikube delete${NC}"
echo ""

echo -e "${GREEN}Deployment complete!${NC}"