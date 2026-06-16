#!/bin/bash
# =============================================================================
# setup-local.sh - Full Environment Setup for Runtime Security Lab
# =============================================================================
# This script verifies prerequisites and prepares the environment for
# deploying the eBPF runtime security stack.
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "🛡️  eBPF Runtime Security Lab - Setup"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# 1. Check prerequisites
# ---------------------------------------------------------------------------
log_info "Checking prerequisites..."

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | head -1 || kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1)
    log_ok "kubectl installed: ${KUBECTL_VERSION}"
else
    log_error "kubectl not found. Install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check helm
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null)
    log_ok "helm installed: ${HELM_VERSION}"
else
    log_warn "helm not found. Installing..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log_ok "helm installed successfully"
fi

# Check cluster connectivity
log_info "Checking cluster connectivity..."
if kubectl cluster-info &> /dev/null; then
    log_ok "Cluster is reachable"
    kubectl get nodes
else
    log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
fi

# Check kernel version (for eBPF support)
KERNEL_VERSION=$(uname -r | cut -d. -f1-2)
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)

if [ "$KERNEL_MAJOR" -gt 5 ] || ([ "$KERNEL_MAJOR" -eq 5 ] && [ "$KERNEL_MINOR" -ge 8 ]); then
    log_ok "Kernel version ${KERNEL_VERSION} supports eBPF"
else
    log_warn "Kernel version ${KERNEL_VERSION} may not fully support eBPF (need 5.8+)"
fi

# ---------------------------------------------------------------------------
# 2. Add Helm repositories
# ---------------------------------------------------------------------------
echo ""
log_info "Adding Helm repositories..."

helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

log_ok "All Helm repositories added and updated"

# ---------------------------------------------------------------------------
# 3. Create namespaces
# ---------------------------------------------------------------------------
echo ""
log_info "Creating namespaces..."

for ns in tetragon kyverno monitoring; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

log_ok "Namespaces created"

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "✅ Environment setup complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Install Tetragon:   bash scripts/install-tetragon.sh"
echo "  2. Install Kyverno:    bash scripts/install-kyverno.sh"
echo "  3. Install Monitoring: bash scripts/install-monitoring.sh"
echo ""
echo "Current cluster state:"
kubectl get nodes -o wide
echo ""
kubectl get namespaces
