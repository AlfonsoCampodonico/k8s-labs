# Lab 08 — Health, resources & autoscaling

> **Est. time:** 4 hours.
> **Prereqs:** labs 02 and 03.

Three distinct concepts students frequently conflate: **probes** tell
the kubelet whether a container is alive/ready/starting, **resources**
tell the scheduler and kernel how much CPU/memory a container expects,
and the **HorizontalPodAutoscaler** adjusts replica counts from observed
metrics. Each solves a different problem.

## Learning outcomes

1. Pick the right probe for a job — `livenessProbe`, `readinessProbe`,
   `startupProbe` — and avoid the classic misconfiguration of using
   liveness to detect slow starts.
2. Explain the relationship between `resources.requests` (scheduling),
   `resources.limits` (enforcement), and QoS classes (eviction order).
3. Install `metrics-server` on kind and read cluster metrics.
4. Configure a HorizontalPodAutoscaler and observe it scaling under
   synthetic load.

## Background

### Probes

| Probe | Purpose | On failure |
|-------|---------|-----------|
| startupProbe | "Is the app finished starting?" | Keep probing; liveness/readiness are skipped during startup |
| readinessProbe | "Can the app serve requests *right now*?" | Remove pod from Service endpoints |
| livenessProbe | "Is the app healthy? (i.e. should I restart it?)" | Restart the container |

Common mistake: a liveness probe with a short initial delay on an app
that takes 60 seconds to boot. The kubelet kills the container mid-boot.
Use a startupProbe instead.

### QoS classes

Derived automatically from requests/limits on every container in the pod:

| Class | Condition |
|-------|-----------|
| `Guaranteed` | Every container has requests == limits for both CPU and memory |
| `Burstable`  | At least one container has requests or limits, but not Guaranteed |
| `BestEffort` | No requests and no limits anywhere |

Under memory pressure the kubelet evicts BestEffort first, then
Burstable with the highest "over-request" ratio, then Guaranteed.

### HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef: { kind: Deployment, name: web, apiVersion: apps/v1 }
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 50 }
```

The HPA controller reads pod metrics via `metrics.k8s.io` (served by
metrics-server), computes the desired replica count, and writes it to
the Deployment's `spec.replicas`. The loop runs every 15 seconds.

## Guided walkthrough

### 1. Install metrics-server (kind-compatible)

```bash
kubectl apply -f manifests/metrics-server.yaml
kubectl -n kube-system rollout status deployment/metrics-server --timeout=120s
kubectl top nodes
kubectl top pods -A
```

### 2. Probes

```bash
kubectl apply -f manifests/probes-demo.yaml
kubectl get pod slow-start -w
# startup probe keeps liveness at bay for the first ~20 seconds
```

### 3. HPA load test

```bash
kubectl apply -f manifests/web-hpa.yaml
kubectl run -it --rm loader --image=busybox:1.36 -- sh
# inside:
while true; do wget -qO- http://web/; done
```

In another terminal:

```bash
kubectl get hpa web -w
```

## Challenges

### C1. A probe-trio

In `lab-08`, a Deployment `api` running `ghcr.io/stefanprodan/podinfo:6.7.1`
with:

- `startupProbe` on `/healthz`, `failureThreshold: 30`, `periodSeconds: 2`
- `readinessProbe` on `/readyz`, `periodSeconds: 5`
- `livenessProbe` on `/healthz`, `periodSeconds: 10`,
  `failureThreshold: 3`
- resources: `requests.cpu=50m`, `requests.memory=64Mi`,
  `limits.cpu=200m`, `limits.memory=128Mi`
- 2 replicas initially

### C2. QoS classes

Create three pods `bestefort`, `burstable`, `guaranteed` in `lab-08`
whose container resource configs land the pod in each respective QoS
class. The verifier inspects `.status.qosClass` directly.

### C3. An autoscaled Deployment

Create an HPA named `api` in `lab-08` targeting the `api` Deployment:

- `minReplicas: 2`
- `maxReplicas: 6`
- average CPU utilization 50%

## Verification

```bash
make verify LAB=08
```

## Further reading

- [Kubernetes Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/).
- [HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/).
- [Node pressure eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/).
