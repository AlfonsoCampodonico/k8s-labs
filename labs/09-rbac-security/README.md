# Lab 09 — RBAC & security

> **Est. time:** 5 hours.
> **Prereqs:** lab 02.

Every request to the API server is **authenticated** (who are you?),
**authorised** (are you allowed?), and **admitted** (is the thing you're
trying to do permitted by cluster policy?). This lab focuses on the
second stage — **Role-Based Access Control** — and complements it with
two other production-grade defences: **NetworkPolicies** and the
**Pod Security Admission** standards.

## Learning outcomes

1. Distinguish Users, Groups, and ServiceAccounts as RBAC subjects.
2. Write Roles, RoleBindings, ClusterRoles, and ClusterRoleBindings
   with least-privilege scopes.
3. Use `kubectl auth can-i` to test authorisation decisions.
4. Write default-deny NetworkPolicies and allow only the traffic you
   want.
5. Label a namespace with `pod-security.kubernetes.io/enforce` to block
   privileged workloads.

## Background

### RBAC model

```
Subject (user / SA / group)
   |
 (Binding)
   |
   v
Role / ClusterRole  — list of (apiGroup, resource, verb) tuples
```

Bindings are namespaced (`RoleBinding`) or cluster-wide
(`ClusterRoleBinding`). ClusterRoles can be re-used inside a namespace
by referencing them from a `RoleBinding`.

### NetworkPolicies

A NetworkPolicy is selected by pod labels. If *any* NetworkPolicy
selects a pod, that pod becomes subject to policy and only explicitly
allowed traffic can flow; pods no NetworkPolicy selects are
unrestricted. Default-deny is therefore a single policy that selects
everything and allows nothing.

You need a CNI that implements NetworkPolicy. kind's default
`kindnet` does. Calico and Cilium both work too.

### Pod Security Admission

PSA is the successor to PodSecurityPolicy. You label a namespace with
one or more of:

- `pod-security.kubernetes.io/enforce=<level>`
- `pod-security.kubernetes.io/audit=<level>`
- `pod-security.kubernetes.io/warn=<level>`

with `level` in `{privileged, baseline, restricted}`. The admission
plugin rejects (or audits/warns about) pods that don't meet the level.

## Guided walkthrough

### 1. A ServiceAccount with list-pods permission

```bash
kubectl apply -f manifests/viewer-role.yaml
kubectl auth can-i list pods --as=system:serviceaccount:default:viewer
# yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:viewer
# no
```

### 2. Use the SA from inside the cluster

```bash
kubectl apply -f manifests/viewer-pod.yaml
kubectl logs viewer-pod
# lists pods using the SA token mounted at /var/run/secrets/...
```

### 3. Default-deny NetworkPolicy

```bash
kubectl create namespace policy-demo
kubectl -n policy-demo apply -f manifests/policy-demo.yaml
kubectl -n policy-demo exec deploy/a -- wget -qO- http://b --timeout=3
# works — no policies yet
kubectl -n policy-demo apply -f manifests/default-deny.yaml
kubectl -n policy-demo exec deploy/a -- wget -qO- http://b --timeout=3
# blocked
kubectl -n policy-demo apply -f manifests/allow-a-to-b.yaml
kubectl -n policy-demo exec deploy/a -- wget -qO- http://b --timeout=3
# works again
```

### 4. Pod Security Admission

```bash
kubectl create namespace restricted
kubectl label ns restricted pod-security.kubernetes.io/enforce=restricted
kubectl -n restricted apply -f manifests/privileged-pod.yaml
# API server rejects it: "violates PodSecurity \"restricted:latest\""
```

## Challenges

### C1. Namespace-scoped viewer SA

In `lab-09`, create:

- a ServiceAccount `reader`
- a Role `pod-reader` allowing `get`, `list`, `watch` on pods
- a RoleBinding binding `reader` → `pod-reader`
- verify with `kubectl auth can-i get pods -n lab-09 --as=system:serviceaccount:lab-09:reader` returning `yes`

### C2. Default-deny + explicit allow

In `lab-09`:

- a Deployment `frontend` (image `nginx:1.27-alpine`, label `app=frontend`)
- a Deployment `backend` (image `nginx:1.27-alpine`, label `app=backend`)
- a Service `backend` selecting `app=backend`
- a NetworkPolicy `default-deny-ingress` that selects every pod and
  denies all ingress
- a NetworkPolicy `allow-frontend-to-backend` that allows ingress to
  `app=backend` pods from `app=frontend` pods on port 80

### C3. Enforce baseline PSA

Label the `lab-09` namespace with
`pod-security.kubernetes.io/enforce=baseline`. Attempt to create a pod
with `privileged: true` and observe the rejection. The verifier checks
the label is set; the rejection is part of the walkthrough.

## Verification

```bash
make verify LAB=09
```

## Further reading

- [RBAC good practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/).
- [NetworkPolicy recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes).
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/).
