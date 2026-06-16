# ADR-001: eBPF-Based Runtime Security with Cilium Tetragon

## Status
**Accepted** — June 2024

## Context

We need a runtime security monitoring solution for our Kubernetes (k3s) cluster that can:

1. Detect security threats in real-time (<5 seconds)
2. Monitor syscalls, network connections, and file access at the kernel level
3. Operate with minimal performance overhead (<5% CPU)
4. Integrate with existing observability stack (Prometheus/Grafana)
5. Enforce security policies at the admission level

### Options Considered

| Solution | Pros | Cons |
|----------|------|------|
| **Cilium Tetragon** | eBPF-native, zero overhead, Prometheus metrics, active development | Newer project, smaller community |
| **Falco** | Mature, large community, extensive rules | Higher overhead, sysdig dependency |
| **Sysdig Secure** | Enterprise features, compliance | Commercial, heavy resource usage |
| **Aqua Security** | Full lifecycle security | Commercial, complex setup |
| **OPA/Gatekeeper** | Flexible policy engine | No runtime monitoring, admission only |

## Decision

We chose **Cilium Tetragon** for runtime monitoring and **Kyverno** for admission control because:

### Tetragon
1. **eBPF-native**: Hooks directly into kernel, providing true zero-overhead monitoring
2. **Prometheus integration**: Built-in metrics export for seamless Grafana dashboards
3. **Real-time detection**: Kernel-level hooks detect events as they happen
4. **Open source**: CNCF project with active community and Cilium backing
5. **K8s-aware**: Understands pod context (namespace, labels) natively

### Kyverno (over OPA/Gatekeeper)
1. **Kubernetes-native**: Uses CRDs, no new language to learn (vs Rego)
2. **YAML-based**: Policies written in familiar YAML format
3. **Built-in reporting**: PolicyReport CRDs for compliance tracking
4. **Generate/Mutate**: Can generate and mutate resources, not just validate

## Consequences

### Positive
- Real-time threat detection with <3s latency
- Zero measurable performance overhead
- Familiar Prometheus/Grafana integration
- Policy enforcement prevents misconfigurations before deployment

### Negative
- Tetragon requires Linux kernel 5.8+ (limits OS choices)
- Kyverno adds admission webhook latency (~50ms per request)
- eBPF programs need privileged DaemonSet on nodes

### Risks
- Tetragon is newer than Falco; fewer community rules available
- eBPF programs can cause kernel issues if poorly written (mitigated by using Tetragon's vetted programs)

## References
- [Cilium Tetragon Documentation](https://tetragon.io/docs/)
- [Kyverno Documentation](https://kyverno.io/docs/)
- [eBPF.io](https://ebpf.io/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
