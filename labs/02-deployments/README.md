# Lab 02 — Deployments & ReplicaSets

> **Est. time:** 4 hours.
> **Prereqs:** lab 01.

Pods die. Nodes die. `kubectl` operators fumble and delete things. If
you want workloads that survive any of that you need a controller that
reconciles for you. In Kubernetes the primary one for stateless
workloads is **Deployment**, which manages **ReplicaSets**, which in
turn manage **Pods**.

## Learning outcomes

1. Explain the relationship between Deployment → ReplicaSet → Pod and
   why two levels of indirection exist.
2. Perform a rolling update with a specific `maxSurge` / `maxUnavailable`
   and reason about its behaviour.
3. Roll back a bad deployment with `kubectl rollout undo`.
4. Use `kubectl rollout` to pause, resume, and watch a rollout.
5. Implement a blue/green or canary pattern on top of Deployments.

## Background

### Why two layers?

A ReplicaSet maintains exactly one replica template. When you change
the template (e.g. bump the image tag) the ReplicaSet has no concept of
"old" and "new"; it just terminates pods that don't match. That's bad
for a rolling update because you lose capacity.

A Deployment solves this by creating *multiple* ReplicaSets — one per
version of the pod template — and shifting replicas from the old RS to
the new one over time. The number of RS objects Kubernetes keeps
around is controlled by `spec.revisionHistoryLimit` (default 10) and
is what `kubectl rollout history` reads.

### Rolling update parameters

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%           # extra pods beyond replicas during rollout
      maxUnavailable: 25%     # pods allowed to be Not Ready during rollout
```

Setting `maxUnavailable: 0` gives you zero-downtime at the cost of
needing headroom for at least one extra pod. Setting `maxSurge: 0`
forces pods to be replaced one-at-a-time within the existing capacity.

### Recreate

`strategy.type: Recreate` kills every pod first, then creates the new
set. Useful for workloads that can't run two versions side-by-side (a
singleton writing to a local file, for instance).

### Rollbacks

Every apply that changes the pod template creates a new revision.
`kubectl rollout undo deployment/web` moves the replica count from the
current RS back to the previous one. This does *not* revert your
manifest — you still have to fix the YAML before the next apply.

## Guided walkthrough

### 1. First rollout

```bash
kubectl apply -f manifests/deploy-v1.yaml
kubectl rollout status deployment/podinfo
kubectl get rs -l app=podinfo
kubectl get pods -l app=podinfo -o wide
```

Notice you have one ReplicaSet. Inspect its name — it contains a hash
of the pod template.

### 2. Rolling update

```bash
kubectl apply -f manifests/deploy-v2.yaml
kubectl rollout status deployment/podinfo
kubectl get rs -l app=podinfo            # two RSs now
kubectl rollout history deployment/podinfo
```

### 3. A bad rollout + rollback

```bash
kubectl apply -f manifests/deploy-bad.yaml
kubectl rollout status deployment/podinfo --timeout=30s   # times out
kubectl get pods -l app=podinfo                            # stuck ImagePullBackOff

kubectl rollout undo deployment/podinfo
kubectl rollout status deployment/podinfo
```

### 4. Pause & resume

Pausing lets you stack multiple changes and commit them in a single
rollout, which is how fleet-scale operators do gradual rollouts:

```bash
kubectl rollout pause deployment/podinfo
kubectl set image deployment/podinfo app=ghcr.io/stefanprodan/podinfo:6.7.1
kubectl set env deployment/podinfo LAB=02
kubectl rollout resume deployment/podinfo
```

## Challenges

### C1. A well-configured Deployment

In the `lab-02` namespace, create a Deployment named `web` with:

- 4 replicas of `ghcr.io/stefanprodan/podinfo:6.7.0`
- labels `app=web`, `lab=02` on the pod template
- `strategy.type=RollingUpdate`, `maxSurge=1`, `maxUnavailable=0`
- resource requests `cpu=25m`, `memory=32Mi`
- readiness probe on `/readyz`:9898
- `revisionHistoryLimit: 5`

### C2. Rolling update, observed

Roll `web` forward to `ghcr.io/stefanprodan/podinfo:6.7.1`. The
verifier checks that the rollout completed cleanly and there are at
least two ReplicaSets on record (one old, one new).

### C3. Canary via a second Deployment

Create a second Deployment named `web-canary` in the same namespace
that is byte-identical to `web` except:

- 1 replica
- image `ghcr.io/stefanprodan/podinfo:6.7.2`
- pod labels include `track=canary` (where `web` should have
  `track=stable`)

Both Deployments will be selected by a single Service in lab 03; for
now just get the two running.

## Verification

```bash
make verify LAB=02
```

## Further reading

- Kubernetes docs: [*Deployments*](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).
- Google SRE, [*Canarying releases*](https://sre.google/workbook/canarying-releases/).
- Marc Brooker, [*Fail at scale*](https://brooker.co.za/blog/2019/11/30/fault.html).
