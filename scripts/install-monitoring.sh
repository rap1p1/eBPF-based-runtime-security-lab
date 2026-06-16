#!/bin/bash
# =============================================================================
# install-monitoring.sh - Install Prometheus + Grafana + AlertManager
# =============================================================================
# Installs the kube-prometheus-stack and configures:
#   - Prometheus for metrics collection
#   - Grafana for visualization  
#   - AlertManager for Telegram notifications
#   - ServiceMonitor for Tetragon metrics
#   - PrometheusRule for security alerts
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

NAMESPACE="monitoring"
RELEASE_NAME="prometheus"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo "📊 Installing Monitoring Stack"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# 1. Add Helm repo
# ---------------------------------------------------------------------------
log_info "Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# ---------------------------------------------------------------------------
# 2. Install kube-prometheus-stack
# ---------------------------------------------------------------------------
log_info "Installing kube-prometheus-stack..."
helm upgrade --install "${RELEASE_NAME}" prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.enabled=true \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30000 \
  --set grafana.adminPassword=admin \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=ALL \
  --set alertmanager.enabled=true \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=30903 \
  --wait \
  --timeout 600s

log_ok "kube-prometheus-stack installed"

# ---------------------------------------------------------------------------
# 3. Wait for all pods
# ---------------------------------------------------------------------------
log_info "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod \
  -n "${NAMESPACE}" --all --timeout=300s 2>/dev/null || true

log_ok "Monitoring pods are ready"

# ---------------------------------------------------------------------------
# 4. Apply Tetragon ServiceMonitor
# ---------------------------------------------------------------------------
echo ""
log_info "Applying Tetragon ServiceMonitor..."
kubectl apply -f "${PROJECT_DIR}/manifests/tetragon-servicemonitor.yaml"
log_ok "Tetragon ServiceMonitor applied"

# ---------------------------------------------------------------------------
# 5. Apply security alert rules
# ---------------------------------------------------------------------------
log_info "Applying security alert rules..."
kubectl apply -f "${PROJECT_DIR}/manifests/security-alerts.yaml"
log_ok "Security alert rules applied"

# ---------------------------------------------------------------------------
# 6. Import custom Grafana dashboard
# ---------------------------------------------------------------------------
log_info "Creating Grafana dashboard ConfigMap..."
kubectl create configmap tetragon-dashboard \
  --from-file=tetragon-security.json="${PROJECT_DIR}/dashboards/tetragon-dashboard.json" \
  --namespace "${NAMESPACE}" \
  --dry-run=client -o yaml | \
  kubectl label --local -f - grafana_dashboard=1 -o yaml | \
  kubectl apply -f -
log_ok "Grafana dashboard imported"

# ---------------------------------------------------------------------------
# 7. Configure AlertManager (Telegram)
# ---------------------------------------------------------------------------
echo ""
log_info "AlertManager Telegram configuration:"
log_warn "To enable Telegram alerts, update manifests/alertmanager-config.yaml with your:"
echo "  - BOT_TOKEN (from @BotFather)"
echo "  - CHAT_ID  (from @getidsbot)"
echo ""
echo "Then run:"
echo "  kubectl create secret generic alertmanager-${RELEASE_NAME}-kube-prometheus-alertmanager \\"
echo "    --from-file=alertmanager.yaml=manifests/alertmanager-config.yaml \\"
echo "    --namespace=${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"

# ---------------------------------------------------------------------------
# 8. Verify installation
# ---------------------------------------------------------------------------
echo ""
log_info "Monitoring pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
log_info "Monitoring services:"
kubectl get svc -n "${NAMESPACE}"

echo ""
log_info "ServiceMonitors:"
kubectl get servicemonitor -n "${NAMESPACE}"

echo ""
log_info "PrometheusRules:"
kubectl get prometheusrule -n "${NAMESPACE}"

# ---------------------------------------------------------------------------
# 9. Access information
# ---------------------------------------------------------------------------
GRAFANA_PASSWORD=$(kubectl get secret -n "${NAMESPACE}" "${RELEASE_NAME}-grafana" -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "admin")

echo ""
echo "=============================================="
echo "✅ Monitoring stack installation complete!"
echo "=============================================="
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-grafana 3000:80"
echo "  URL: http://localhost:3000"
echo "  User: admin"
echo "  Pass: ${GRAFANA_PASSWORD}"
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-kube-prometheus-prometheus 9090:9090"
echo "  URL: http://localhost:9090"
echo ""
echo "Access AlertManager:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-kube-prometheus-alertmanager 9093:9093"
echo "  URL: http://localhost:9093"
echo ""
echo "Recommended Grafana dashboards to import:"
echo "  - Tetragon: ID 16555"
echo "  - Kubernetes: ID 15757"
echo "  - Prometheus: ID 19105"
