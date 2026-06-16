#!/bin/bash
# =============================================================================
# simulate-reverse-shell.sh - Reverse Shell Attack Simulation
# =============================================================================
# Simulates a reverse shell attack to demonstrate Tetragon's detection
# capabilities. This script:
#   1. Creates a vulnerable pod (running as root)
#   2. Installs netcat inside the pod
#   3. Attempts to establish a reverse shell listener
#   4. Monitors Tetragon logs for detection
#   5. Cleans up all resources
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
POD_NAME="vuln-reverse-shell"
TETRAGON_NS="tetragon"

echo "=============================================="
echo "🔴 ATTACK SIMULATION: Reverse Shell"
echo "=============================================="
echo ""
log_warn "⚠️  This is a security test - FOR TESTING ONLY"
echo ""

# Record start time
START_TIME=$(date +%s)

# ---------------------------------------------------------------------------
# 1. Create vulnerable pod
# ---------------------------------------------------------------------------
log_attack "Step 1: Creating vulnerable pod..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: vuln-reverse-shell
    test: attack-simulation
spec:
  containers:
    - name: attacker
      image: alpine:latest
      command: ["sleep", "3600"]
      securityContext:
        runAsUser: 0
      resources:
        limits:
          cpu: "200m"
          memory: "128Mi"
EOF

log_info "Waiting for pod to be ready..."
kubectl wait --for=condition=ready "pod/${POD_NAME}" -n "${NAMESPACE}" --timeout=60s
log_ok "Vulnerable pod created and running"

# ---------------------------------------------------------------------------
# 2. Simulate attack
# ---------------------------------------------------------------------------
echo ""
log_attack "Step 2: Installing attack tools (netcat)..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "apk add --no-cache netcat-openbsd 2>/dev/null || apk add --no-cache nmap-ncat 2>/dev/null || true"

echo ""
log_attack "Step 3: Attempting reverse shell listener on port 4444..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "nc -l -p 4444 &" 2>/dev/null &
EXEC_PID=$!

sleep 3

log_attack "Step 4: Executing suspicious commands..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "whoami; id; cat /etc/passwd | head -5" 2>/dev/null || true
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "wget --spider http://evil.example.com 2>/dev/null" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Check Tetragon detection
# ---------------------------------------------------------------------------
echo ""
log_detect "Step 5: Checking Tetragon detection logs..."

TETRAGON_POD=$(kubectl get pods -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "${TETRAGON_POD}" ]; then
    echo ""
    log_detect "=== Tetragon Process Events ==="
    kubectl logs -n "${TETRAGON_NS}" "${TETRAGON_POD}" -c tetragon --since=2m 2>/dev/null | \
        grep -i "exec\|process\|${POD_NAME}" | tail -20 || \
        log_warn "No events found in Tetragon logs (check if exports are configured)"
    
    echo ""
    log_detect "=== Tetragon Network Events ==="
    kubectl logs -n "${TETRAGON_NS}" "${TETRAGON_POD}" -c tetragon --since=2m 2>/dev/null | \
        grep -i "network\|connect\|socket\|4444" | tail -10 || \
        log_warn "No network events found"
fi

# Calculate detection time
END_TIME=$(date +%s)
DETECTION_TIME=$((END_TIME - START_TIME))

echo ""
echo "=============================================="
log_ok "Detection time: ${DETECTION_TIME} seconds"
echo "=============================================="

# ---------------------------------------------------------------------------
# 4. Cleanup
# ---------------------------------------------------------------------------
echo ""
log_info "Cleaning up..."
kill "${EXEC_PID}" 2>/dev/null || true
kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false

echo ""
echo "=============================================="
echo "✅ Reverse shell simulation complete!"
echo "=============================================="
echo ""
echo "📊 Check Grafana dashboard for visualization"
echo "🔔 Check Telegram for alerts"
echo "📝 Detection time: ${DETECTION_TIME}s (target: <5s)"
