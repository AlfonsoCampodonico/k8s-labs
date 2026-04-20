# Lab 06 — StatefulSets

> **Est. time:** 5 hours.
> **Prereqs:** labs 03 and 05.

Deployments treat their pods as interchangeable. That is a disaster
for clustered databases, queues, or any workload where pod `web-0`
owns shard 0, pod `web-1` owns shard 1, and the two must address
each other stably. A **StatefulSet** gives each pod:

- An ordinal identity (`mysql-0`, `mysql-1`, …).
- A stable DNS name via a **headless Service**.
- A dedicated PersistentVolumeClaim from a `volumeClaimTemplates`.
- Ordered rollout and deletion (pod *n* only after pod *n-1* is Ready).

## Learning outcomes

1. Build a StatefulSet backed by a headless Service and observe
   `pod-N.svc.ns.svc.cluster.local` DNS records.
2. Understand `volumeClaimTemplates` and that deleting a StatefulSet
   does **not** delete its PVCs.
3. Use `podManagementPolicy: Parallel` when ordering is not required.
4. Perform a rolling update and observe the ordered rollout.
5. Scale a StatefulSet up and down and reason about data lifecycle.

## Background

The simplest correct mental model: a StatefulSet is a Deployment that
also materialises a PVC per replica, never reuses pod names, and
rolls out one pod at a time from highest ordinal to lowest.

A **headless Service** (`clusterIP: None`) paired with the
StatefulSet is what enables per-pod DNS — the DNS server returns one
A record per pod (for the Service name) and additionally publishes
`{pod}.{service}.{ns}.svc.cluster.local` for each pod.

## Guided walkthrough

### 1. A three-node "database"

```bash
kubectl apply -f manifests/db-headless.yaml
kubectl apply -f manifests/db-sts.yaml
kubectl -n default rollout status statefulset/db --timeout=180s
kubectl get pods -l app=db -o wide
kubectl get pvc -l app=db
```

### 2. Stable identity via DNS

```bash
kubectl run -it --rm shell --image=busybox:1.36 -- sh
# inside:
nslookup db                      # headless — returns three A records
nslookup db-0.db                 # returns only pod db-0's IP
nslookup db-1.db
```

### 3. Delete a pod, keep the data

```bash
kubectl delete pod db-1
kubectl get pod db-1              # re-created with the same name + same PVC
kubectl exec db-1 -- cat /data/identity
```

### 4. Scale down

```bash
kubectl scale statefulset db --replicas=2
kubectl get pvc -l app=db         # PVC for db-2 is still present!
```

Deleting the StatefulSet with `cascade=orphan` leaves pods and PVCs
behind — useful during migrations.

## Challenges

### C1. Ordered nginx

In namespace `lab-06`, create:

- a headless Service `web` targeting `app=web` on port 80
- a StatefulSet `web` with 3 replicas of `nginx:1.27-alpine`
  - `serviceName: web`
  - `podManagementPolicy: OrderedReady`
  - `volumeClaimTemplates` creating 500Mi RWO PVCs named `html`
  - the pod mounts the PVC at `/usr/share/nginx/html`
  - an init container seeds the PVC with a file
    `/usr/share/nginx/html/index.html` whose contents are
    `hello from $(hostname)`

### C2. Stable DNS

From a throwaway pod, `wget -qO- http://web-0.web.lab-06` must return
the text containing `web-0`, and likewise for `web-1` and `web-2`.

### C3. Scale down without losing data

Scale `web` to 1 replica, then back to 3. The verifier checks that
`web-1` and `web-2` still serve the *original* seed content (not a
freshly seeded one), which proves the PVCs were preserved across the
scale-down.

## Verification

```bash
make verify LAB=06
```

## Further reading

- Kubernetes docs: [*StatefulSets*](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).
- Janet Kuo, [*StatefulSets: deep dive*](https://www.youtube.com/watch?v=pPQKAR1pA9U).
- [*Writing a StatefulSet operator*](https://sdk.operatorframework.io/docs/building-operators/) when StatefulSets aren't enough.
