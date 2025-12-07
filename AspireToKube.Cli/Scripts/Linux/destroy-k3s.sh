#!/bin/bash
# Interactive Cleanup Script for Kubernetes Environment
# Allows selective removal of deployed resources
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

echo "================================================"
echo "  Interactive Cleanup - Remove Kubernetes Resources"
echo "================================================"
echo ""

# Get namespace
NAMESPACE="${NAMESPACE:-default}"
echo -e "${CYAN}Namespace: ${YELLOW}${NAMESPACE}${NC}"
echo ""

# Check if namespace exists and has resources
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Namespace '${NAMESPACE}' does not exist${NC}"
    exit 1
fi

echo -e "${CYAN}Checking resources in namespace...${NC}"
echo ""

# Function to count resources
count_resources() {
    local resource_type=$1
    kubectl get "$resource_type" -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l
}

# Function to display resource counts
display_resources() {
    local resource_type=$1
    local display_name=$2
    local count=$(count_resources "$resource_type")
    
    if [ "$count" -gt 0 ]; then
        echo -e "${YELLOW}  [$count] ${display_name}${NC}"
        return 0
    else
        echo -e "${GRAY}  [0] ${display_name}${NC}"
        return 1
    fi
}

# Detect available resources
echo -e "${CYAN}Available resources:${NC}"
HAS_DEPLOYMENTS=false
HAS_STATEFULSETS=false
HAS_DAEMONSETS=false
HAS_SERVICES=false
HAS_INGRESSES=false
HAS_CONFIGMAPS=false
HAS_SECRETS=false
HAS_PVCS=false
HAS_JOBS=false
HAS_CRONJOBS=false
HAS_PODS=false

display_resources "deployments" "Deployments" && HAS_DEPLOYMENTS=true || true
display_resources "statefulsets" "StatefulSets" && HAS_STATEFULSETS=true || true
display_resources "daemonsets" "DaemonSets" && HAS_DAEMONSETS=true || true
display_resources "services" "Services" && HAS_SERVICES=true || true
display_resources "ingress" "Ingresses" && HAS_INGRESSES=true || true
display_resources "configmaps" "ConfigMaps" && HAS_CONFIGMAPS=true || true
display_resources "secrets" "Secrets" && HAS_SECRETS=true || true
display_resources "pvc" "PersistentVolumeClaims" && HAS_PVCS=true || true
display_resources "jobs" "Jobs" && HAS_JOBS=true || true
display_resources "cronjobs" "CronJobs" && HAS_CRONJOBS=true || true
display_resources "pods" "Pods" && HAS_PODS=true || true

echo ""

# Check if there are any resources
TOTAL_RESOURCES=$(count_resources "deployments")
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "statefulsets")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "daemonsets")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "services")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "ingress")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "configmaps")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "secrets")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "pvc")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "jobs")))
TOTAL_RESOURCES=$((TOTAL_RESOURCES + $(count_resources "cronjobs")))

if [ "$TOTAL_RESOURCES" -eq 0 ]; then
    echo -e "${GREEN}No resources found in namespace '${NAMESPACE}'${NC}"
    exit 0
fi

# Cleanup mode selection
echo -e "${YELLOW}Select cleanup mode:${NC}"
echo "  1) Delete ALL resources (quick cleanup)"
echo "  2) Select specific resource types to delete"
echo "  3) Preview resources first"
echo "  4) Cancel"
echo ""
read -p "Enter your choice (1-4): " -r CLEANUP_MODE
echo ""

case "$CLEANUP_MODE" in
    1)
        # Quick cleanup - delete everything
        echo -e "${RED}WARNING: This will delete ALL resources in namespace '${NAMESPACE}'${NC}"
        echo ""
        read -p "Are you absolutely sure? Type 'yes' to confirm: " -r CONFIRM
        echo ""
        
        if [[ ! "$CONFIRM" == "yes" ]]; then
            echo -e "${CYAN}Cleanup cancelled${NC}"
            exit 0
        fi
        
        # Delete everything
        DELETE_DEPLOYMENTS=true
        DELETE_STATEFULSETS=true
        DELETE_DAEMONSETS=true
        DELETE_SERVICES=true
        DELETE_INGRESSES=true
        DELETE_CONFIGMAPS=true
        DELETE_SECRETS=true
        DELETE_PVCS=true
        DELETE_JOBS=true
        DELETE_CRONJOBS=true
        DELETE_PODS=true
        ;;
        
    2)
        # Selective cleanup
        echo -e "${YELLOW}Select resource types to delete:${NC}"
        echo ""
        
        # Ask for each resource type
        DELETE_DEPLOYMENTS=false
        DELETE_STATEFULSETS=false
        DELETE_DAEMONSETS=false
        DELETE_SERVICES=false
        DELETE_INGRESSES=false
        DELETE_CONFIGMAPS=false
        DELETE_SECRETS=false
        DELETE_PVCS=false
        DELETE_JOBS=false
        DELETE_CRONJOBS=false
        DELETE_PODS=false
        
        if [ "$HAS_DEPLOYMENTS" = true ]; then
            read -p "Delete Deployments? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_DEPLOYMENTS=true
        fi
        
        if [ "$HAS_STATEFULSETS" = true ]; then
            read -p "Delete StatefulSets? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_STATEFULSETS=true
        fi
        
        if [ "$HAS_DAEMONSETS" = true ]; then
            read -p "Delete DaemonSets? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_DAEMONSETS=true
        fi
        
        if [ "$HAS_SERVICES" = true ]; then
            read -p "Delete Services? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_SERVICES=true
        fi
        
        if [ "$HAS_INGRESSES" = true ]; then
            read -p "Delete Ingresses? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_INGRESSES=true
        fi
        
        if [ "$HAS_CONFIGMAPS" = true ]; then
            read -p "Delete ConfigMaps? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_CONFIGMAPS=true
        fi
        
        if [ "$HAS_SECRETS" = true ]; then
            read -p "Delete Secrets? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_SECRETS=true
        fi
        
        if [ "$HAS_PVCS" = true ]; then
            read -p "Delete PersistentVolumeClaims? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_PVCS=true
        fi
        
        if [ "$HAS_JOBS" = true ]; then
            read -p "Delete Jobs? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_JOBS=true
        fi
        
        if [ "$HAS_CRONJOBS" = true ]; then
            read -p "Delete CronJobs? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_CRONJOBS=true
        fi
        
        if [ "$HAS_PODS" = true ]; then
            read -p "Delete orphaned Pods? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && DELETE_PODS=true
        fi
        
        echo ""
        ;;
        
    3)
        # Preview resources
        echo -e "${CYAN}=== Resource Preview ===${NC}"
        echo ""
        
        if [ "$HAS_DEPLOYMENTS" = true ]; then
            echo -e "${YELLOW}Deployments:${NC}"
            kubectl get deployments -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_STATEFULSETS" = true ]; then
            echo -e "${YELLOW}StatefulSets:${NC}"
            kubectl get statefulsets -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_DAEMONSETS" = true ]; then
            echo -e "${YELLOW}DaemonSets:${NC}"
            kubectl get daemonsets -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_SERVICES" = true ]; then
            echo -e "${YELLOW}Services:${NC}"
            kubectl get services -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_INGRESSES" = true ]; then
            echo -e "${YELLOW}Ingresses:${NC}"
            kubectl get ingress -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_CONFIGMAPS" = true ]; then
            echo -e "${YELLOW}ConfigMaps:${NC}"
            kubectl get configmaps -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_SECRETS" = true ]; then
            echo -e "${YELLOW}Secrets:${NC}"
            kubectl get secrets -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_PVCS" = true ]; then
            echo -e "${YELLOW}PersistentVolumeClaims:${NC}"
            kubectl get pvc -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_JOBS" = true ]; then
            echo -e "${YELLOW}Jobs:${NC}"
            kubectl get jobs -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_CRONJOBS" = true ]; then
            echo -e "${YELLOW}CronJobs:${NC}"
            kubectl get cronjobs -n "$NAMESPACE"
            echo ""
        fi
        
        if [ "$HAS_PODS" = true ]; then
            echo -e "${YELLOW}Pods:${NC}"
            kubectl get pods -n "$NAMESPACE"
            echo ""
        fi
        
        echo -e "${CYAN}Run the script again to delete resources${NC}"
        exit 0
        ;;
        
    4|*)
        echo -e "${CYAN}Cleanup cancelled${NC}"
        exit 0
        ;;
esac

# Confirm deletion
echo -e "${YELLOW}Resources selected for deletion:${NC}"
SELECTED_COUNT=0

[ "$DELETE_DEPLOYMENTS" = true ] && echo "  • Deployments" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_STATEFULSETS" = true ] && echo "  • StatefulSets" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_DAEMONSETS" = true ] && echo "  • DaemonSets" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_SERVICES" = true ] && echo "  • Services" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_INGRESSES" = true ] && echo "  • Ingresses" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_CONFIGMAPS" = true ] && echo "  • ConfigMaps" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_SECRETS" = true ] && echo "  • Secrets" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_PVCS" = true ] && echo "  • PersistentVolumeClaims" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_JOBS" = true ] && echo "  • Jobs" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_CRONJOBS" = true ] && echo "  • CronJobs" && SELECTED_COUNT=$((SELECTED_COUNT + 1))
[ "$DELETE_PODS" = true ] && echo "  • Orphaned Pods" && SELECTED_COUNT=$((SELECTED_COUNT + 1))

if [ "$SELECTED_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No resources selected for deletion${NC}"
    exit 0
fi

echo ""
read -p "Proceed with deletion? (y/N): " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Cleanup cancelled${NC}"
    exit 0
fi

# Perform deletion
echo -e "${YELLOW}Deleting resources...${NC}"
echo ""

if [ "$DELETE_DEPLOYMENTS" = true ] && [ "$HAS_DEPLOYMENTS" = true ]; then
    echo -e "${CYAN}Deleting Deployments...${NC}"
    kubectl delete deployment --all -n "$NAMESPACE" --grace-period=30 2>/dev/null && \
        echo -e "${GREEN}  ✓ Deployments deleted${NC}" || \
        echo -e "${GRAY}  • No Deployments to delete${NC}"
fi

if [ "$DELETE_STATEFULSETS" = true ] && [ "$HAS_STATEFULSETS" = true ]; then
    echo -e "${CYAN}Deleting StatefulSets...${NC}"
    kubectl delete statefulset --all -n "$NAMESPACE" --grace-period=30 2>/dev/null && \
        echo -e "${GREEN}  ✓ StatefulSets deleted${NC}" || \
        echo -e "${GRAY}  • No StatefulSets to delete${NC}"
fi

if [ "$DELETE_DAEMONSETS" = true ] && [ "$HAS_DAEMONSETS" = true ]; then
    echo -e "${CYAN}Deleting DaemonSets...${NC}"
    kubectl delete daemonset --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ DaemonSets deleted${NC}" || \
        echo -e "${GRAY}  • No DaemonSets to delete${NC}"
fi

if [ "$DELETE_SERVICES" = true ] && [ "$HAS_SERVICES" = true ]; then
    echo -e "${CYAN}Deleting Services...${NC}"
    kubectl delete service --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ Services deleted${NC}" || \
        echo -e "${GRAY}  • No Services to delete${NC}"
fi

if [ "$DELETE_INGRESSES" = true ] && [ "$HAS_INGRESSES" = true ]; then
    echo -e "${CYAN}Deleting Ingresses...${NC}"
    kubectl delete ingress --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ Ingresses deleted${NC}" || \
        echo -e "${GRAY}  • No Ingresses to delete${NC}"
fi

if [ "$DELETE_CONFIGMAPS" = true ] && [ "$HAS_CONFIGMAPS" = true ]; then
    echo -e "${CYAN}Deleting ConfigMaps...${NC}"
    kubectl delete configmap --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ ConfigMaps deleted${NC}" || \
        echo -e "${GRAY}  • No ConfigMaps to delete${NC}"
fi

if [ "$DELETE_SECRETS" = true ] && [ "$HAS_SECRETS" = true ]; then
    echo -e "${CYAN}Deleting Secrets...${NC}"
    kubectl delete secret --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ Secrets deleted${NC}" || \
        echo -e "${GRAY}  • No Secrets to delete${NC}"
fi

if [ "$DELETE_PVCS" = true ] && [ "$HAS_PVCS" = true ]; then
    echo -e "${CYAN}Deleting PersistentVolumeClaims...${NC}"
    kubectl delete pvc --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ PVCs deleted${NC}" || \
        echo -e "${GRAY}  • No PVCs to delete${NC}"
fi

if [ "$DELETE_JOBS" = true ] && [ "$HAS_JOBS" = true ]; then
    echo -e "${CYAN}Deleting Jobs...${NC}"
    kubectl delete jobs --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ Jobs deleted${NC}" || \
        echo -e "${GRAY}  • No Jobs to delete${NC}"
fi

if [ "$DELETE_CRONJOBS" = true ] && [ "$HAS_CRONJOBS" = true ]; then
    echo -e "${CYAN}Deleting CronJobs...${NC}"
    kubectl delete cronjobs --all -n "$NAMESPACE" 2>/dev/null && \
        echo -e "${GREEN}  ✓ CronJobs deleted${NC}" || \
        echo -e "${GRAY}  • No CronJobs to delete${NC}"
fi

if [ "$DELETE_PODS" = true ] && [ "$HAS_PODS" = true ]; then
    echo -e "${CYAN}Deleting orphaned Pods...${NC}"
    kubectl delete pods --all -n "$NAMESPACE" --grace-period=0 --force 2>/dev/null && \
        echo -e "${GREEN}  ✓ Pods deleted${NC}" || \
        echo -e "${GRAY}  • No Pods to delete${NC}"
fi

echo ""

# Optional: Delete namespace
if [ "$NAMESPACE" != "default" ] && [ "$NAMESPACE" != "kube-system" ] && [ "$NAMESPACE" != "kube-public" ] && [ "$NAMESPACE" != "kube-node-lease" ]; then
    echo ""
    read -p "Delete the entire namespace '$NAMESPACE'? (y/N): " -n 1 -r
    echo ""
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Deleting namespace '${NAMESPACE}'...${NC}"
        kubectl delete namespace "$NAMESPACE" 2>/dev/null && \
            echo -e "${GREEN}✓ Namespace deleted${NC}" || \
            echo -e "${YELLOW}• Namespace already deleted or cannot be deleted${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo ""

# Show remaining resources
echo -e "${CYAN}Remaining resources in namespace '${NAMESPACE}':${NC}"
if kubectl get all -n "$NAMESPACE" 2>/dev/null | grep -q "No resources found"; then
    echo -e "${GREEN}✓ All resources removed${NC}"
else
    kubectl get all -n "$NAMESPACE" 2>/dev/null || echo -e "${GREEN}✓ Namespace cleaned${NC}"
fi

echo ""