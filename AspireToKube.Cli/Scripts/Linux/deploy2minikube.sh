#!/bin/bash

# Generic Aspire / minikube deployment script
# Run from directory that contains:
#   - manifests/
#   - *.tar (custom images)
#   - optional top-level kustomization.yaml (applied last)
#
# Prerequisites:
#   - minikube is already started
#   - kubectl is configured to talk to the minikube cluster
#     (e.g. `kubectl config use-context minikube` OR use `minikube kubectl --`)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "================================================"
echo "  ECS Application Deployment (minikube)"
echo "================================================"
echo ""

BASE_DIR="$(pwd)"
MANIFESTS_DIR="${BASE_DIR}/manifests"

if [ ! -d "$MANIFESTS_DIR" ]; then
    echo -e "${RED}manifests/ folder not found in current directory.${NC}"
    echo "Run this script from the Aspire-Migration folder."
    exit 1
fi

# -------------------------------------------------------
# Check minikube status
# -------------------------------------------------------
if ! command -v minikube &>/dev/null; then
    echo -e "${RED}minikube not found in PATH. Install minikube first.${NC}"
    exit 1
fi

echo -e "${CYAN}Checking minikube status...${NC}"
if ! minikube status >/dev/null 2>&1; then
    echo -e "${RED}minikube is not running or not configured correctly.${NC}"
    echo "Start it with: minikube start"
    exit 1
fi

# -------------------------------------------------------
# kubectl wrapper: prefer kubectl, fallback to minikube kubectl
# -------------------------------------------------------
kc() {
    if command -v kubectl &>/dev/null; then
        kubectl "$@"
    else
        minikube kubectl -- "$@"
    fi
}

# -------------------------------------------------------
# Helper: prepare secrets for a single kustomization dir
# (same logic as k3s script)
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

    # If non-interactive, just warn
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
    # Try to use docker images list (most common when minikube uses Docker driver)
    if command -v docker &>/dev/null; then
        existing_images="$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null || true)"
    else
        existing_images=""
    fi

    for tar in "${tar_files[@]}"; do
        tar_name="$(basename "$tar")"
        guess="${tar_name%.tar}"

        if [ -n "$existing_images" ] && echo "$existing_images" | grep -q "$guess"; then
            echo -e "  ${CYAN}${tar_name}${NC} -> image containing '${guess}' already present, skipping import."
            continue
        fi

        echo -e "  Importing ${CYAN}${tar_name}${NC}..."

        if command -v docker &>/dev/null; then
            # Common case: minikube uses the same docker daemon
            docker load -i "$tar" >/dev/null
        elif command -v nerdctl &>/dev/null; then
            # In case someone uses containerd with nerdctl
            nerdctl load -i "$tar" >/dev/null
        elif command -v ctr &>/dev/null; then
            # Very generic fallback for containerd-based setups
            ctr -n k8s.io images import "$tar" >/dev/null
        else
            # Last resort, try minikube image load (for non-docker runtimes)
            if minikube image load "$tar" >/dev/null 2>&1; then
                :
            else
                echo -e "${RED}    Could not find a compatible tool to import $tar.${NC}"
                echo -e "${YELLOW}    You may need to manually load this image into minikube.${NC}"
            fi
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
# 3) Status + how to access
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

echo "================================================"
echo "  Access Information"
echo "================================================"
echo ""

echo -e "${YELLOW}Your services are deployed to minikube!${NC}"
echo ""
echo -e "${CYAN}To access a NodePort or LoadBalancer service, for example 'webfrontend':${NC}"
echo "  minikube service webfrontend --url"
echo ""
echo -e "${CYAN}To open the Kubernetes dashboard (if enabled):${NC}"
echo "  minikube dashboard"
echo ""
echo -e "${YELLOW}To use k9s for management (if installed):${NC}"
echo -e "  ${CYAN}k9s${NC}"
echo ""

echo -e "${GREEN}Deployment complete!${NC}"
