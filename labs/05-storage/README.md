# Lab 05 — Storage

> **Est. time:** 4 hours.
> **Prereqs:** lab 02.

Most interesting applications need storage that outlives a pod. This
lab teaches the three-level abstraction Kubernetes uses: **Volume**
(what a pod sees), **PersistentVolume** (a cluster-wide resource),
and **StorageClass** (a template for dynamically provisioning PVs).

## Learning outcomes

1. Distinguish volume types that are pod-scoped (`emptyDir`, `hostPath`,
   `projected`) from cluster-scoped (`persistentVolumeClaim`).
2. Bind a PVC to a pre-provisioned PV manually.
3. Use the kind default StorageClass (`standard` / `rancher.io/local-path`)
   for dynamic provisioning.
4. Reason about `accessModes` (RWO vs. ROX vs. RWX) and
   `reclaimPolicy` (Delete, Retain).
5. Observe that pod restarts preserve data; PVC deletion does not.

## Background

### What "local-path" provisioner does on kind

kind ships with Rancher's `local-path-provisioner`, which creates
PersistentVolumes backed by `hostPath` directories on the node. Every
PV is RWO and tied to a single node. That's fine for labs; it is a
terrible choice for production (no replication, no resizing, no
snapshots) but it is a realistic stand-in for a CSI driver.

### Binding lifecycle

```
PVC created → controller finds matching PV (or provisions one)
            → bind (PVC.spec.volumeName = PV, PV.spec.claimRef = PVC)
            → pod scheduled onto a node that can mount the volume
```

For a dynamic StorageClass, step 1 triggers the provisioner, which
creates a new PV. For a pre-provisioned PV you create the PV yourself
and the scheduler still needs to respect its `nodeAffinity`.

### accessModes

| Mode | Meaning |
|------|---------|
| `ReadWriteOnce` (RWO) | One *node* at a time (many pods on the same node are OK since 1.22 with `ReadWriteOncePod` for the stricter semantics) |
| `ReadOnlyMany` (ROX)  | Many nodes, read-only |
| `ReadWriteMany` (RWX) | Many nodes, read-write — needs NFS/CephFS-style driver |
| `ReadWriteOncePod` (RWOP) | Exactly one pod |

## Guided walkthrough

### 1. Default StorageClass

```bash
kubectl get storageclass
# NAME (default)   PROVISIONER             RECLAIMPOLICY  ...
# standard         rancher.io/local-path   Delete
```

### 2. Dynamic PVC

```bash
kubectl apply -f manifests/pvc-dynamic.yaml
kubectl get pvc
# Pending at first — binding is lazy until a pod mounts it
kubectl apply -f manifests/writer-dynamic.yaml
kubectl get pvc
# Now Bound
kubectl exec deploy/writer -- sh -c 'cat /data/log.txt'
```

Delete just the pod and recreate the Deployment; the data survives:

```bash
kubectl delete deploy writer
kubectl apply -f manifests/writer-dynamic.yaml
kubectl exec deploy/writer -- sh -c 'cat /data/log.txt'
```

Delete the PVC and the data is gone (reclaimPolicy `Delete`):

```bash
kubectl delete pvc data
```

### 3. Pre-provisioned PV

```bash
kubectl apply -f manifests/pv-static.yaml
kubectl apply -f manifests/pvc-static.yaml
kubectl apply -f manifests/writer-static.yaml
```

Note how `pv-static.yaml` declares a `nodeAffinity` — the PV is only
usable from one node, so the scheduler has to put the pod there.

## Challenges

### C1. Persistent podinfo

In `lab-05`, deploy `ghcr.io/stefanprodan/podinfo:6.7.1` with a PVC
named `podinfo-data` (1Gi, RWO, default StorageClass) mounted at
`/data`. The pod must stay Ready.

### C2. Survive a pod restart

Exec into the pod and `echo hello > /data/hello.txt`. Delete the pod
and let the Deployment recreate it. The file must still exist.

### C3. Static PV you cannot dynamically provision

Create a PV named `archive` with `capacity=500Mi`, `hostPath: /var/local/archive`,
`storageClassName: ""` (empty — not dynamic), `accessModes: [ReadOnlyMany]`,
`reclaimPolicy: Retain`. Then a PVC named `archive` in `lab-05` that
binds to it. The verifier confirms the PVC is `Bound` and references
that specific PV.

Reference solution is in `solutions/` if you get stuck.

## Verification

```bash
make verify LAB=05
```

## Further reading

- [Kubernetes Storage Concepts](https://kubernetes.io/docs/concepts/storage/).
- [CSI spec](https://github.com/container-storage-interface/spec).
- Rancher's [local-path-provisioner](https://github.com/rancher/local-path-provisioner).
