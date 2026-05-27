# Scribe — architecture

```
+-----------+        +------------+        +-----------+        +-----------+
|  browser  |  HTTP  |  frontend  |  HTTP  |  backend  |  TCP   | postgres  |
+-----------+ -----> | (nginx)    | -----> | (podinfo) | -----> | (single   |
                    +------------+        +-----------+        |  pod STS) |
                          ^                     ^               +-----------+
                          |                     |
                  Ingress (host:                HPA (CPU 50%,
                  scribe.k8s-labs.test)         min 2 / max 6)
```

## Components

### frontend — `nginx:1.27-alpine`
Serves static assets and reverse-proxies `/api` to the `backend` Service.
Two replicas behind a ClusterIP service. The Ingress points here.

- **Failure mode**: process exits or fails its `/` readiness check.
  Deployment replaces the pod; rolling update guarantees one Ready
  pod throughout.
- **Restart story**: stateless; the Deployment controller recreates
  pods on any node.
- **Scaling**: increase `frontend.replicas`. No state, so horizontal
  scaling is linear.

### backend — `ghcr.io/stefanprodan/podinfo:6.7.1`
Stateless HTTP service. Reads `DATABASE_URL` from Secret
`postgres-credentials` and feature flags from ConfigMap `backend-config`.
An HPA scales it from 2 → 6 on CPU utilisation = 50%.

- **Failure mode**: pod dies → ReplicaSet recreates; HPA scales on
  load.
- **Restart story**: stateless; no PVC.
- **Scaling**: HPA already automated; if request volume exceeds
  ~max replicas, raise `maxReplicas` and `requests.cpu` headroom.

### postgres — `postgres:16-alpine`
StatefulSet of one replica with a headless Service and a PVC. Single
writer; the schema bootstraps on first start from a script in the
ConfigMap `postgres-init`.

- **Failure mode**: pod dies → StatefulSet recreates the same pod
  name (`postgres-0`) with the same PVC, so data survives.
- **Restart story**: the PVC's `Retain`-policy storage class would
  keep data across cluster rebuilds; on the standard kind storage
  class, deletion of the PVC loses data.
- **Scaling**: single-writer Postgres does not scale horizontally
  by adding replicas. Real prod uses streaming replication +
  read-replicas, or a managed service. Out of scope for this lab.

## Cross-cutting

- **NetworkPolicies** implement default-deny ingress, then open
  `frontend → backend → postgres` explicitly. Anything else is
  dropped.
- **PSA**: namespace enforces `baseline` so privileged pods are
  rejected at admission.
- **Resource budgets**: every container declares CPU+memory
  requests and limits, so the scheduler can pack the cluster and
  the kubelet can enforce isolation.
