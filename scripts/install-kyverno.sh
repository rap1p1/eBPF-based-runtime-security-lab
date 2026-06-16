#!/bin/bash
# =============================================================================
# install-kyverno.sh - Install Kyverno + Apply Security Policies
# =============================================================================
# Installs Kyverno policy engine and applies all security policies from
# the policies/ directory.
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

NAMESPACE="kyverno"
RELEASE_NAME="kyverno"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo "📋 Installing Kyverno Policy Engine"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# 1. Add Helm repo
# ---------------------------------------------------------------------------
log_info "Adding Kyverno Helm repository..."
helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
helm repo update

# ---------------------------------------------------------------------------
# 2. Install Kyverno
# ---------------------------------------------------------------------------
log_info "Installing Kyverno with Helm..."
helm upgrade --install "${RELEASE_NAME}" kyverno/kyverno \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set admissionController.replicas=2 \
  --set cleanupController.replicas=1 \
  --set reportsController.replicas=1 \
  --set backgroundController.replicas=1 \
  --wait \
  --timeout 300s

log_ok "Kyverno Helm release installed"

# ---------------------------------------------------------------------------
# 3. Wait for all deployments
# ---------------------------------------------------------------------------
log_info "Waiting for Kyverno deployments to be ready..."
kubectl wait --for=condition=available deployment \
  -n "${NAMESPACE}" --all --timeout=120s

log_ok "All Kyverno deployments ready"

# ---------------------------------------------------------------------------
# 4. Verify installation
# ---------------------------------------------------------------------------
echo ""
log_info "Kyverno pods:"
kubectl get pods -n "${NAMESPACE}" -o wide

echo ""
log_info "Webhook configurations:"
kubectl get validatingwebhookconfigurations | grep kyverno || true
kubectl get mutatingwebhookconfigurations | grep kyverno || true

# ---------------------------------------------------------------------------
# 5. Apply security policies
# ---------------------------------------------------------------------------
echo ""
log_info "Applying security policies..."

POLICY_DIR="${PROJECT_DIR}/policies"
POLICY_COUNT=0

for policy_file in "${POLICY_DIR}"/*.yaml; do
    if [ -f "$policy_file" ]; then
        POLICY_NAME=$(basename "$policy_file")
        log_info "  Applying: ${POLICY_NAME}"
        kubectl apply -f "$policy_file"
        POLICY_COUNT=$((POLICY_COUNT + 1))
    fi
done

log_ok "${POLICY_COUNT} policies applied"

# ---------------------------------------------------------------------------
# 6. Verify policies
# ---------------------------------------------------------------------------
echo ""
log_info "Cluster policies status:"
kubectl get clusterpolicies

# ---------------------------------------------------------------------------
# 7. Test policy enforcement
# ---------------------------------------------------------------------------
echo ""
log_info "Testing policy enforcement..."

# Test: Privileged pod should be BLOCKED
echo ""
log_info "Test 1: Deploying privileged pod (should be BLOCKED)..."
if kubectl apply -f "${PROJECT_DIR}/manifests/test-privileged.yaml" 2>&1 | tee /tmp/kyverno-test-result.txt; then
    log_error "FAILED: Privileged pod was allowed (policy not enforcing)"
    kubectl delete -f "${PROJECT_DIR}/manifests/test-privileged.yaml" --ignore-not-found 2>/dev/null || true
else
    if grep -qi "denied\|blocked\|validate" /tmp/kyverno-test-result.txt; then
        log_ok "PASSED: Privileged pod was blocked by Kyverno ✅"
    else
        log_warn "Pod creation failed but not clearly by Kyverno"
    fi
fi

# Test: Compliant pod should be ALLOWED
echo ""
log_info "Test 2: Deploying compliant pod (should be ALLOWED)..."
if kubectl apply -f "${PROJECT_DIR}/manifests/test-compliant.yaml" 2>&1; then
    log_ok "PASSED: Compliant pod was allowed ✅"
    kubectl delete -f "${PROJECT_DIR}/manifests/test-compliant.yaml" --ignore-not-found --wait=false 2>/dev/null || true
else
    log_error "FAILED: Compliant pod was blocked (check policy configuration)"
fi

rm -f /tmp/kyverno-test-result.txt

# ---------------------------------------------------------------------------
# 8. Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "✅ Kyverno installation complete!"
echo "=============================================="
echo ""
echo "Policies enforced:"
echo "  🔒 require-non-root          (Medium)"
echo "  🔒 block-privileged          (High)"
echo "  🔒 require-readonly-rootfs   (Medium)"
echo "  🔒 block-host-network-pid    (High)"
echo "  🔒 require-resource-limits   (Medium)"
echo ""
echo "Next step: bash scripts/install-monitoring.sh"
