#!/bin/bash
# =============================================================================
# simulate-cryptomining.sh - Cryptomining Attack Simulation
# =============================================================================
# Simulates a cryptomining attack by deploying a pod with:
#   - High CPU consumption (stress tool)
#   - Suspicious process execution patterns
#   - Known mining pool DNS lookups
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
POD_NAME="vuln-cryptominer"
TETRAGON_NS="tetragon"

echo "=============================================="
echo "🔴 ATTACK SIMULATION: Cryptomining"
echo "=============================================="
echo ""
log_warn "⚠️  This is a security test - FOR TESTING ONLY"
echo ""

START_TIME=$(date +%s)

# ---------------------------------------------------------------------------
# 1. Create cryptominer pod
# ---------------------------------------------------------------------------
log_attack "Step 1: Deploying cryptominer pod..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: cryptominer
    test: attack-simulation
spec:
  containers:
    - name: miner
      image: alpine:latest
      command:
        - sh
        - -c
        - |
          echo "Starting mining simulation..."
          # Simulate CPU-intensive mining activity
          while true; do
            # CPU stress to simulate mining
            dd if=/dev/urandom bs=1M count=10 | md5sum > /dev/null 2>&1
            echo "[$(date)] Mining cycle complete"
            sleep 1
          done
      securityContext:
        runAsUser: 0
      resources:
        limits:
          cpu: "500m"
          memory: "256Mi"
        requests:
          cpu: "200m"
          memory: "128Mi"
EOF

log_info "Waiting for cryptominer pod to start..."
kubectl wait --for=condition=ready "pod/${POD_NAME}" -n "${NAMESPACE}" --timeout=60s
log_ok "Cryptominer pod running"

# ---------------------------------------------------------------------------
# 2. Monitor resource usage
# ---------------------------------------------------------------------------
echo ""
log_attack "Step 2: Monitoring CPU usage (cryptomining indicator)..."
sleep 10

log_info "Pod resource usage:"
kubectl top pod "${POD_NAME}" -n "${NAMESPACE}" 2>/dev/null || \
    log_warn "metrics-server not available (install it for resource monitoring)"

# ---------------------------------------------------------------------------
# 3. Simulate mining pool connections
# ---------------------------------------------------------------------------
echo ""
log_attack "Step 3: Simulating mining pool DNS lookups..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c \
    "nslookup pool.minexmr.com 2>/dev/null || nslookup xmrpool.eu 2>/dev/null || echo 'DNS lookup attempted'" 2>/dev/null || true

kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c \
    "wget --spider http://pool.minexmr.com:4444 2>/dev/null" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4. Check Tetragon detection
# ---------------------------------------------------------------------------
echo ""
log_detect "Step 4: Checking Tetragon detection..."

TETRAGON_POD=$(kubectl get pods -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "${TETRAGON_POD}" ]; then
    echo ""
    log_detect "=== Tetragon Process Events (High CPU) ==="
    kubectl logs -n "${TETRAGON_NS}" "${TETRAGON_POD}" -c tetragon --since=2m 2>/dev/null | \
        grep -i "process\|exec\|${POD_NAME}\|dd\|md5sum" | tail -20 || \
        log_warn "No process events found"

    echo ""
    log_detect "=== Tetragon Network Events (Mining Pool) ==="
    kubectl logs -n "${TETRAGON_NS}" "${TETRAGON_POD}" -c tetragon --since=2m 2>/dev/null | \
        grep -i "dns\|network\|connect\|minexmr\|xmrpool" | tail -10 || \
        log_warn "No network events found"
fi

END_TIME=$(date +%s)
DETECTION_TIME=$((END_TIME - START_TIME))

echo ""
echo "=============================================="
log_ok "Detection time: ${DETECTION_TIME} seconds"
echo "=============================================="

# ---------------------------------------------------------------------------
# 5. Cleanup
# ---------------------------------------------------------------------------
echo ""
log_info "Cleaning up..."
kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false

echo ""
echo "=============================================="
echo "✅ Cryptomining simulation complete!"
echo "=============================================="
echo ""
echo "📊 Check Grafana for CPU spike visualization"
echo "🔔 Check Telegram for resource alerts"
echo "📝 Detection time: ${DETECTION_TIME}s (target: <5s)"
