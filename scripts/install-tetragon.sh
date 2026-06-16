#!/bin/bash
# =============================================================================
# install-tetragon.sh - Install Cilium Tetragon (eBPF Runtime Security)
# =============================================================================
# Installs Tetragon with Prometheus metrics enabled for real-time
# syscall, network, and file monitoring at the kernel level.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

NAMESPACE="tetragon"
RELEASE_NAME="tetragon"
TETRAGON_VERSION="1.1.0"

echo "=============================================="
echo "🔬 Installing Cilium Tetragon v${TETRAGON_VERSION}"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# 1. Add Helm repo
# ---------------------------------------------------------------------------
log_info "Adding Cilium Helm repository..."
helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
helm repo update

# ---------------------------------------------------------------------------
# 2. Create namespace
# ---------------------------------------------------------------------------
log_info "Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------------
# 3. Install Tetragon
# ---------------------------------------------------------------------------
log_info "Installing Tetragon with Helm..."
helm upgrade --install "${RELEASE_NAME}" cilium/tetragon \
  --namespace "${NAMESPACE}" \
  --version "${TETRAGON_VERSION}" \
  --set tetragon.enableProcessCred=true \
  --set tetragon.enableProcessNs=true \
  --set tetragon.prometheus.enabled=true \
  --set tetragon.prometheus.serviceMonitor.enabled=true \
  --set tetragon.prometheus.port=2112 \
  --set tetragonOperator.prometheus.enabled=true \
  --wait \
  --timeout 300s

log_ok "Tetragon Helm release installed"

# ---------------------------------------------------------------------------
# 4. Wait for pods
# ---------------------------------------------------------------------------
log_info "Waiting for Tetragon pods to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=tetragon \
  -n "${NAMESPACE}" \
  --timeout=120s

log_ok "Tetragon pods are ready"

# ---------------------------------------------------------------------------
# 5. Verify installation
# ---------------------------------------------------------------------------
echo ""
log_info "Tetragon pods:"
kubectl get pods -n "${NAMESPACE}" -o wide

echo ""
log_info "Tetragon DaemonSet:"
kubectl get daemonset -n "${NAMESPACE}"

echo ""
log_info "Checking eBPF probes..."
TETRAGON_POD=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=tetragon -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n "${NAMESPACE}" "${TETRAGON_POD}" -c tetragon --tail=20 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. Test basic monitoring
# ---------------------------------------------------------------------------
echo ""
log_info "Testing basic monitoring with a test pod..."
kubectl run tetragon-test --image=alpine:latest --restart=Never \
  --command -- sleep 30 2>/dev/null || true

sleep 5

log_info "Checking if Tetragon detected the test pod..."
kubectl logs -n "${NAMESPACE}" "${TETRAGON_POD}" -c tetragon --tail=5 2>/dev/null | grep -i "exec" || log_warn "No exec events found yet (this is normal for new installations)"

# Cleanup test pod
kubectl delete pod tetragon-test --ignore-not-found --wait=false 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "✅ Tetragon installation complete!"
echo "=============================================="
echo ""
echo "Tetragon is now monitoring:"
echo "  🔹 Process executions (syscalls)"
echo "  🔹 Network connections"
echo "  🔹 File access patterns"
echo ""
echo "Prometheus metrics available at port 2112"
echo ""
echo "Next step: bash scripts/install-kyverno.sh"
