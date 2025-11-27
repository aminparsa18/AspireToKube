#!/bin/bash

# Generic Aspire / k3s deployment script
# Run from directory that contains:
#   - manifests/
#   - *.tar (custom images)
#   - aspirate-state.json (for secrets)
#   - optional top-level kustomization.yaml (applied last)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "================================================"
echo "  ECS Application Deployment"
echo "================================================"
echo ""

BASE_DIR="$(pwd)"
MANIFESTS_DIR="${BASE_DIR}/manifests"

if [ ! -d "$MANIFESTS_DIR" ]; then
    echo -e "${RED}manifests/ folder not found in current directory.${NC}"
    echo "Run this script from the Aspire-Migration folder."
    exit 1
fi

# Setup kubectl access for k3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export PATH="/usr/local/bin:$PATH"

if ! command -v k3s &>/dev/null; then
    echo -e "${RED}Error: k3s is required but not installed.${NC}"
    echo -e "${YELLOW}Please run the init command first:${NC}"
    echo -e "${CYAN}  aspire2kube init --distro <your-distribution>${NC}"
    echo ""
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}Error: python3 is required but not installed.${NC}"
    echo -e "${YELLOW}Please run the init command first:${NC}"
    echo -e "${CYAN}  aspire2kube init --distro <your-distribution>${NC}"
    echo ""
    exit 1
fi

K3S_BIN="$(command -v k3s)"

kc() {
    if command -v kubectl &>/dev/null; then
        kubectl "$@"
    else
        "${K3S_BIN}" kubectl "$@"
    fi
}

# -------------------------------------------------------
# Helper: Parse aspirate-state.json and create secret files
# -------------------------------------------------------
process_aspirate_secrets() {
    local state_file="${BASE_DIR}/aspirate-state.json"
    
    if [ ! -f "$state_file" ]; then
        echo -e "${YELLOW}No aspirate-state.json found, skipping secret generation.${NC}"
        return 0
    fi

    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        echo -e "${YELLOW}Please run the init command first:${NC}"
        echo -e "${CYAN}  aspire2kube init --distro <your-distribution>${NC}"
        echo ""
        exit 1
    fi

    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}Error: python3 is required but not installed.${NC}"
        echo -e "${YELLOW}Please run the init command first:${NC}"
        echo -e "${CYAN}  aspire2kube init --distro <your-distribution>${NC}"
        echo ""
        exit 1
    fi

    echo -e "${CYAN}Processing secrets from aspirate-state.json...${NC}"
    echo ""

    # Check if secrets section exists
    if ! jq -e '.secrets.secrets' "$state_file" >/dev/null 2>&1; then
        echo -e "${YELLOW}No secrets section found in aspirate-state.json${NC}"
        return 0
    fi

    # Check if secrets appear to be encrypted
    local sample_secret
    sample_secret=$(jq -r '.secrets.secrets | to_entries | .[0].value | to_entries | .[0].value // empty' "$state_file" 2>/dev/null || echo "")
    
    local NEEDS_DECRYPTION=false
    if [ -n "$sample_secret" ] && [[ "$sample_secret" =~ ^[A-Za-z0-9+/]{20,}={0,2}$ ]]; then
        NEEDS_DECRYPTION=true
    fi

    if [ "$NEEDS_DECRYPTION" = "true" ]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⚠  Secrets are ENCRYPTED and need decryption${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Get the directory where this script is located
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        DECRYPT_SCRIPT="${SCRIPT_DIR}/decrypt-secrets.py"
        
        # Check if decrypt-secrets.py exists in the same directory as this script
        if [ ! -f "$DECRYPT_SCRIPT" ]; then
            echo -e "${RED}Error: decrypt-secrets.py not found${NC}"
            echo -e "${YELLOW}Expected location: ${DECRYPT_SCRIPT}${NC}"
            echo -e "${YELLOW}Please ensure decrypt-secrets.py is in the same directory as deploy2k3s.sh${NC}"
            exit 1
        fi

        # Check if Python cryptography is available
        if ! python3 -c "import cryptography" 2>/dev/null; then
            echo -e "${RED}Error: Python cryptography library not installed${NC}"
            echo -e "${YELLOW}Please run: pip3 install --break-system-packages cryptography${NC}"
            exit 1
        fi

        echo -e "${CYAN}Running automatic decryption...${NC}"
        echo ""
        
        # Run the decryption script (it will work in the current directory for aspirate-state.json)
        if python3 "$DECRYPT_SCRIPT"; then
            echo ""
            echo -e "${GREEN}Secrets decrypted successfully!${NC}"
            echo ""
        else
            echo ""
            echo -e "${RED}Decryption failed!${NC}"
            echo -e "${YELLOW}Please check your password and try again${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Secrets appear to be already decrypted${NC}"
        echo ""
        
        # Process unencrypted secrets
        local service_names
        mapfile -t service_names < <(jq -r '.secrets.secrets | keys[]' "$state_file" 2>/dev/null || true)

        if [ "${#service_names[@]}" -eq 0 ]; then
            echo -e "${YELLOW}No services with secrets found in aspirate-state.json${NC}"
            return 0
        fi

        for service_name in "${service_names[@]}"; do
            local service_dir="${MANIFESTS_DIR}/${service_name}"
            
            # Skip if the service directory doesn't exist
            if [ ! -d "$service_dir" ]; then
                continue
            fi

            # Check if service has any secrets (not just an empty object)
            local secret_count
            secret_count=$(jq -r ".secrets.secrets.\"${service_name}\" | length" "$state_file" 2>/dev/null || echo "0")
            
            if [ "$secret_count" -eq 0 ]; then
                continue
            fi

            local secret_file="${service_dir}/.${service_name}.secrets"
            
            # Skip if secret file already exists and is not empty
            if [ -f "$secret_file" ] && [ -s "$secret_file" ]; then
                echo -e "${GREEN}  Secret file for '${service_name}' already exists${NC}"
                continue
            fi
            
            echo -e "${CYAN}  Creating secrets for '${service_name}'...${NC}"
            
            # Create or overwrite the secret file
            : > "$secret_file"
            chmod 600 "$secret_file"

            # Extract all key-value pairs for this service and write to secret file
            # Use jq to properly handle Unicode escapes and get raw output
            local secrets_json
            secrets_json=$(jq -c ".secrets.secrets.\"${service_name}\"" "$state_file" 2>/dev/null || echo "{}")
            
            # Process each key-value pair
            while IFS="=" read -r key value; do
                if [ -n "$key" ] && [ -n "$value" ]; then
                    echo "${key}=${value}" >> "$secret_file"
                    echo -e "${GREEN}    Added: ${key}${NC}"
                fi
            done < <(echo "$secrets_json" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || true)

            echo -e "${GREEN}  Created ${secret_file}${NC}"
            echo ""
        done
    fi

    echo -e "${GREEN}Secret processing complete${NC}"
    echo ""
}

# -------------------------------------------------------
# 1) Import all .tar images (for your custom services)
# -------------------------------------------------------
echo -e "${YELLOW}[1/4] Importing container images from *.tar (if needed)...${NC}"

shopt -s nullglob
tar_files=("$BASE_DIR"/*.tar)
shopt -u nullglob

if [ "${#tar_files[@]}" -eq 0 ]; then
    echo -e "${YELLOW}No .tar files found, skipping image import.${NC}"
else
    existing_images="$(sudo "$K3S_BIN" crictl images 2>/dev/null || true)"

    for tar in "${tar_files[@]}"; do
        tar_name="$(basename "$tar")"
        guess="${tar_name%.tar}"
        if echo "$existing_images" | grep -q "$guess"; then
            echo -e "  ${CYAN}${tar_name}${NC} -> image containing '${guess}' already present, skipping import."
        else
            echo -e "  Importing ${CYAN}${tar_name}${NC}..."
            sudo "$K3S_BIN" ctr -n k8s.io images import "$tar"
        fi
    done
fi

echo -e "${GREEN}Image import phase finished.${NC}"
echo ""

# -------------------------------------------------------
# 2) Process secrets from aspirate-state.json
# -------------------------------------------------------
echo -e "${YELLOW}[2/4] Processing secrets from aspirate-state.json...${NC}"
process_aspirate_secrets

# -------------------------------------------------------
# 3) Deploy every kustomization under manifests/
# -------------------------------------------------------
echo -e "${YELLOW}[3/4] Applying manifests for all services...${NC}"

for dir in "$MANIFESTS_DIR"/*; do
    [ -d "$dir" ] || continue
    svc="$(basename "$dir")"

    if [ -f "$dir/kustomization.yaml" ] || [ -f "$dir/kustomization.yml" ]; then
        echo -e "${YELLOW}Deploying ${svc}...${NC}"
        kc apply -k "$dir"
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
    kc apply -k "$BASE_DIR"
    echo -e "${GREEN}Top-level kustomization deployed${NC}"
    echo ""
fi

# -------------------------------------------------------
# 4) Status + URLs
# -------------------------------------------------------
echo "================================================"
echo "  Deployment Status"
echo "================================================"
echo ""

echo -e "${CYAN}Pods:${NC}"
kc get pods
echo ""

echo -e "${CYAN}Services:${NC}"
kc get services
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "================================================"
echo "  Access Information"
echo "================================================"
echo ""

echo -e "${YELLOW}Your services are deployed!${NC}"
echo ""
echo -e "${CYAN}To access services via NodePort (if used):${NC}"
echo ""

echo ""
echo -e "${YELLOW}To use k9s for management:${NC}"
echo -e "  ${CYAN}k9s${NC}"
echo ""

echo -e "${GREEN}Deployment complete!${NC}"