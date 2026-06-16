#!/bin/bash
# =============================================================================
# simulate-priv-escalation.sh - Privilege Escalation Attack Simulation
# =============================================================================
# Simulates multiple privilege escalation attempts to demonstrate
# Kyverno's policy enforcement:
#   1. Privileged container deployment
#   2. Host network namespace access
#   3. Host PID namespace access
#   4. Root user container
#
# ⚠️  FOR TESTING PURPOSES ONLY - Do not run in production!
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_attack(){ echo -e "${RED}[ATTACK]${NC} $1"; }
log_detect(){ echo -e "${CYAN}[DETECT]${NC} $1"; }

NAMESPACE="default"
KYVERNO_NS="kyverno"
RESULTS=()
PASSED=0
FAILED=0

echo "=============================================="
echo "🔴 ATTACK SIMULATION: Privilege Escalation"
echo "=============================================="
echo ""
log_warn "⚠️  This is a security test - FOR TESTING ONLY"
echo ""

# ---------------------------------------------------------------------------
# Helper: Test if a pod deployment is blocked
# ---------------------------------------------------------------------------
test_blocked() {
    local test_name="$1"
    local yaml_content="$2"
    
    log_attack "Testing: ${test_name}..."
    
    if echo "${yaml_content}" | kubectl apply -f - 2>&1 | grep -qi "denied\|blocked\|validate\|error"; then
        log_ok "BLOCKED ✅ - ${test_name}"
        RESULTS+=("✅ BLOCKED: ${test_name}")
        PASSED=$((PASSED + 1))
    else
        log_error "ALLOWED ❌ - ${test_name}"
        RESULTS+=("❌ ALLOWED: ${test_name}")
        FAILED=$((FAILED + 1))
        # Cleanup if pod was created
        local pod_name=$(echo "${yaml_content}" | grep "name:" | head -1 | awk '{print $2}')
        kubectl delete pod "${pod_name}" -n "${NAMESPACE}" --ignore-not-found --wait=false 2>/dev/null || true
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Test 1: Privileged Container
# ---------------------------------------------------------------------------
test_blocked "Privileged Container" '
apiVersion: v1
kind: Pod
metadata:
  name: test-priv-esc-privileged
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        privileged: true
        runAsUser: 0
'

# ---------------------------------------------------------------------------
# Test 2: Host Network Access
# ---------------------------------------------------------------------------
test_blocked "Host Network Access" '
apiVersion: v1
kind: Pod
metadata:
  name: test-priv-esc-hostnetwork
  namespace: default
spec:
  hostNetwork: true
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        readOnlyRootFilesystem: true
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
'

# ---------------------------------------------------------------------------
# Test 3: Host PID Access
# ---------------------------------------------------------------------------
test_blocked "Host PID Namespace" '
apiVersion: v1
kind: Pod
metadata:
  name: test-priv-esc-hostpid
  namespace: default
spec:
  hostPID: true
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        readOnlyRootFilesystem: true
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
'

# ---------------------------------------------------------------------------
# Test 4: Root User Container
# ---------------------------------------------------------------------------
test_blocked "Root User Container" '
apiVersion: v1
kind: Pod
metadata:
  name: test-priv-esc-root
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        runAsNonRoot: false
        runAsUser: 0
        readOnlyRootFilesystem: true
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
'

# ---------------------------------------------------------------------------
# Test 5: No Resource Limits
# ---------------------------------------------------------------------------
test_blocked "No Resource Limits" '
apiVersion: v1
kind: Pod
metadata:
  name: test-priv-esc-nolimits
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        readOnlyRootFilesystem: true
'

# ---------------------------------------------------------------------------
# Test 6: Writable Root Filesystem
# ---------------------------------------------------------------------------
test_blocked "Writable Root Filesystem" '
apiVersion: v1
kind: Pod
metadata:
  name: test-priv-esc-writable
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        readOnlyRootFilesystem: false
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
'

# ---------------------------------------------------------------------------
# Check Kyverno logs
# ---------------------------------------------------------------------------
echo ""
log_detect "Checking Kyverno admission controller logs..."
kubectl logs -n "${KYVERNO_NS}" -l app.kubernetes.io/component=admission-controller --tail=30 2>/dev/null | \
    grep -i "denied\|blocked\|policy\|violation" | tail -10 || \
    log_warn "No policy events found in Kyverno logs"

# ---------------------------------------------------------------------------
# Results Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "📊 PRIVILEGE ESCALATION TEST RESULTS"
echo "=============================================="
echo ""
for result in "${RESULTS[@]}"; do
    echo "  ${result}"
done
echo ""
echo "  Total: $((PASSED + FAILED)) tests"
echo "  Passed: ${PASSED} ✅"
echo "  Failed: ${FAILED} ❌"
echo ""

if [ "${FAILED}" -eq 0 ]; then
    echo "🎉 All privilege escalation attempts were blocked!"
else
    echo "⚠️  ${FAILED} test(s) failed - review Kyverno policy configuration"
fi

echo ""
echo "=============================================="
echo "✅ Privilege escalation simulation complete!"
echo "=============================================="
echo ""
echo "📊 Check Grafana for policy violation metrics"
echo "🔔 Check Telegram for security alerts"
