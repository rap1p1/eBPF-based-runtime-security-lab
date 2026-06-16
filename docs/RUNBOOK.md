# Operational Runbook: eBPF Runtime Security

## Table of Contents
1. [Daily Operations](#daily-operations)
2. [Incident Response Procedures](#incident-response-procedures)
3. [Maintenance Tasks](#maintenance-tasks)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [Escalation Matrix](#escalation-matrix)

---

## Daily Operations

### Morning Checklist

```bash
# 1. Verify all security components are running
kubectl get pods -n tetragon
kubectl get pods -n kyverno
kubectl get pods -n monitoring

# 2. Check for active alerts
kubectl get prometheusrule -n monitoring
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093 &
# Check http://localhost:9093/#/alerts

# 3. Verify policy enforcement
kubectl get clusterpolicies
kubectl get policyreport -A

# 4. Quick Grafana check
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
# Check http://localhost:3000 dashboards
```

---

## Incident Response Procedures

### High Process Execution Rate

**Alert**: `HighProcessExecutionRate`  
**Severity**: Warning  
**Threshold**: >100 exec/5m for 2 minutes

**Steps**:
1. Identify the affected pod:
   ```bash
   kubectl top pods --sort-by=cpu -A
   ```
2. Check Tetragon logs for the pod:
   ```bash
   TETRAGON_POD=$(kubectl get pods -n tetragon -l app.kubernetes.io/name=tetragon -o jsonpath='{.items[0].metadata.name}')
   kubectl logs -n tetragon $TETRAGON_POD -c tetragon --since=5m | grep "<pod-name>"
   ```
3. If malicious: Delete the pod and investigate the deployment
   ```bash
   kubectl delete pod <pod-name> -n <namespace>
   kubectl describe deployment <deployment-name> -n <namespace>
   ```
4. If legitimate: Update alert threshold or add exception

### Reverse Shell Detected

**Alert**: `ReverseShellDetected`  
**Severity**: Critical

**Steps**:
1. **IMMEDIATELY** isolate the pod:
   ```bash
   kubectl label pod <pod-name> quarantine=true -n <namespace>
   kubectl annotate pod <pod-name> incident="reverse-shell-$(date +%s)" -n <namespace>
   ```
2. Capture forensic data:
   ```bash
   kubectl logs <pod-name> -n <namespace> > /tmp/incident-pod-logs.txt
   kubectl describe pod <pod-name> -n <namespace> > /tmp/incident-pod-describe.txt
   kubectl get events -n <namespace> --sort-by='.metadata.creationTimestamp' > /tmp/incident-events.txt
   ```
3. Check Tetragon for full process tree:
   ```bash
   kubectl logs -n tetragon $TETRAGON_POD -c tetragon --since=10m | grep "<pod-name>" > /tmp/incident-tetragon.txt
   ```
4. Kill the pod:
   ```bash
   kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
   ```
5. Investigate the deployment source and container image
6. File incident report

### Privileged Container Attempt

**Alert**: `PrivilegedContainerAttempt`  
**Severity**: Critical

**Steps**:
1. This is already blocked by Kyverno (no container was created)
2. Check Kyverno logs for details:
   ```bash
   kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=50
   ```
3. Identify who/what attempted the deployment
4. Review RBAC permissions

---

## Maintenance Tasks

### Weekly
- Review Grafana dashboards for anomalies
- Check Prometheus storage usage
- Verify all policies are active: `kubectl get clusterpolicies`

### Monthly
- Update Tetragon to latest version
- Review and update alert thresholds
- Run all attack simulation scripts
- Update Kyverno policies as needed

### Quarterly
- Full security audit
- Review compliance status (CIS Benchmark)
- Update documentation
- Conduct team training

---

## Troubleshooting Guide

### Tetragon Not Starting

```bash
# Check kernel version
uname -r  # Need 5.8+

# Check BPF filesystem
mount | grep bpf

# Check Tetragon DaemonSet
kubectl describe daemonset tetragon -n tetragon

# Check pod logs
kubectl logs -n tetragon -l app.kubernetes.io/name=tetragon -c tetragon --tail=50
```

### Kyverno Webhook Errors

```bash
# Check webhook configuration
kubectl get validatingwebhookconfigurations kyverno-resource-validating-webhook-cfg -o yaml

# Check Kyverno pods
kubectl get pods -n kyverno
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=50

# Restart Kyverno if needed
kubectl rollout restart deployment -n kyverno kyverno-admission-controller
```

### Prometheus Not Scraping

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Check targets in Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090
# Visit: http://localhost:9090/targets

# Check Tetragon metrics endpoint
TETRAGON_POD=$(kubectl get pods -n tetragon -l app.kubernetes.io/name=tetragon -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tetragon $TETRAGON_POD -c tetragon -- wget -qO- http://localhost:2112/metrics | head -20
```

---

## Escalation Matrix

| Severity | Response Time | Notification | Action |
|----------|--------------|--------------|--------|
| Critical | Immediate | Telegram + Email | Stop attack, capture evidence |
| Warning | 15 minutes | Telegram | Investigate and document |
| Info | Next business day | Dashboard only | Review in daily standup |
