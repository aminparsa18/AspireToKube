#!/bin/bash

# Generic Aspire / k3s deployment script
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
    echo -e "${RED}k3s binary not found in PATH. This script assumes k3s is installed.${NC}"
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
        # This service doesn't use secretGenerator envs; nothing to do.
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

    # Find {placeholders} in the kustomization (e.g. {cache-password-uri-encoded.value})
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
        read -s -p "  Enter value for ${ph}: " val
        echo
        if [ -z "$val" ]; then
            echo -e "${RED}  No value entered; skipping ${ph}. You can edit secrets file manually later.${NC}"
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
# 1) Import all .tar images (for your custom services)
# -------------------------------------------------------
echo -e "${YELLOW}[1/3] Importing container images from *.tar (if needed)...${NC}"

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
# 2) Deploy every kustomization under manifests/
# -------------------------------------------------------
echo -e "${YELLOW}[2/3] Applying manifests for all services...${NC}"

for dir in "$MANIFESTS_DIR"/*; do
    [ -d "$dir" ] || continue
    svc="$(basename "$dir")"

    if [ -f "$dir/kustomization.yaml" ] || [ -f "$dir/kustomization.yml" ]; then
        echo -e "${YELLOW}Deploying ${svc}...${NC}"
        prepare_kustomization_secrets "$dir"
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
    prepare_kustomization_secrets "$BASE_DIR"
    kc apply -k "$BASE_DIR"
    echo -e "${GREEN}Top-level kustomization deployed${NC}"
    echo ""
fi

# -------------------------------------------------------
# 3) Status + URLs
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
