#!/bin/bash

# Quick Cleanup Script for Test Environment
# Removes all deployed resources

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "================================================"
echo "  Quick Cleanup - Remove Test Resources"
echo "================================================"
echo ""

NAMESPACE="${NAMESPACE:-default}"

echo -e "${YELLOW}This will delete ALL resources in namespace: ${NAMESPACE}${NC}"
echo ""

kubectl get all -n "$NAMESPACE" 2>/dev/null || {
    echo -e "${YELLOW}No resources found or cannot access cluster${NC}"
    exit 0
}

echo ""
read -p "Are you sure you want to delete everything? (yes/NO): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${CYAN}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting resources...${NC}"
echo ""

# Delete specific resources
echo -e "${CYAN}Deleting deployments...${NC}"
kubectl delete deployment --all -n "$NAMESPACE" 2>/dev/null || echo "  No deployments"

echo -e "${CYAN}Deleting statefulsets...${NC}"
kubectl delete statefulset --all -n "$NAMESPACE" 2>/dev/null || echo "  No statefulsets"

echo -e "${CYAN}Deleting services...${NC}"
kubectl delete service --all -n "$NAMESPACE" 2>/dev/null || echo "  No services"

echo -e "${CYAN}Deleting secrets...${NC}"
kubectl delete secret --all -n "$NAMESPACE" 2>/dev/null || echo "  No secrets"

echo -e "${CYAN}Deleting configmaps...${NC}"
kubectl delete configmap --all -n "$NAMESPACE" 2>/dev/null || echo "  No configmaps"

echo -e "${CYAN}Deleting persistent volume claims...${NC}"
kubectl delete pvc --all -n "$NAMESPACE" 2>/dev/null || echo "  No PVCs"

echo -e "${CYAN}Deleting pods (forced)...${NC}"
kubectl delete pods --all -n "$NAMESPACE" --grace-period=0 --force 2>/dev/null || echo "  No pods"

echo ""

if [ "$NAMESPACE" != "default" ]; then
    read -p "Delete namespace '$NAMESPACE'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace "$NAMESPACE" 2>/dev/null || echo "  Namespace already deleted"
        echo -e "${GREEN}Namespace deleted${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Cleanup complete!${NC}"
echo ""
echo -e "${CYAN}Verify cleanup:${NC}"
kubectl get all -n "$NAMESPACE" 2>/dev/null || echo -e "${GREEN}All resources removed${NC}"