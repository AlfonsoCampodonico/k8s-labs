# Lab 04 — ConfigMaps & Secrets

> **Est. time:** 3 hours.
> **Prereqs:** lab 02.

Stateless workloads still have configuration: feature flags, database
URLs, TLS bundles, credentials. Kubernetes has two first-class objects
for that — **ConfigMaps** (non-sensitive) and **Secrets** (sensitive).
Both can be injected as environment variables, command-line flags, or
mounted as files. This lab teaches when to use which.

## Learning outcomes

1. Create ConfigMaps and Secrets from literals, files, and directories.
2. Inject configuration as env vars vs. mounted files and explain why
   you would pick each.
3. Understand the reload semantics of projected volumes (do pods
   restart? When?).
4. Use *immutable* ConfigMaps and the trade-offs.
5. Explain why Secrets at rest are only `base64`-encoded by default,
   and what encryption-at-rest actually requires.

## Background

### ConfigMap vs. Secret

They are almost the same object: a map from string keys to arbitrary
bytes. Secrets differ in that they:

- Are not printed in `kubectl describe` output (the values are elided).
- Can be backed by an encryption-at-rest provider via `EncryptionConfiguration`
  on the API server.
- Are scheduled with a soft anti-collocation hint by the kubelet.
- Should be treated as sensitive even though the default on-disk form
  (`/registry/secrets` in etcd) is unencrypted base64.

### Env vars vs. file mounts

| Property | Env vars | File mount |
|----------|----------|-----------|
| Changes when source updates | No — fixed at pod start | Yes — kubelet resyncs roughly every `configMapAndSecretChangeDetectionStrategy` period (default cache TTL ~1 min) |
| Visible in `/proc/<pid>/environ` | Yes (leaks to forks) | No |
| Size limit | 1 MB per Secret, ~1 MB per ConfigMap | Same |
| Suited for | Small flags, URLs | TLS bundles, config files |

Rule of thumb: **mount** credentials as files, **env** only for
non-sensitive scalars.

### Immutable ConfigMaps

`spec.immutable: true` tells the API server to reject any update to a
ConfigMap or Secret. Combined with versioned names (`app-config-v7`)
this lets you do atomic rollouts of configuration by changing which
ConfigMap a Deployment references; there are no in-place mutations the
kubelet has to reconcile.

## Guided walkthrough

### 1. ConfigMap from a literal

```bash
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-literal=FEATURE_X=true
kubectl describe configmap app-config
```

### 2. ConfigMap from a file

```bash
cat > /tmp/app.conf <<'EOF'
log.level = info
feature.x = true
EOF
kubectl create configmap app-file --from-file=/tmp/app.conf
kubectl get configmap app-file -o yaml
```

### 3. Consume as env vars

```bash
kubectl apply -f manifests/consumer-env.yaml
kubectl logs deploy/consumer-env
```

The pod prints the env vars it received.

### 4. Consume as a volume

```bash
kubectl apply -f manifests/consumer-file.yaml
kubectl exec deploy/consumer-file -- ls /etc/app
kubectl exec deploy/consumer-file -- cat /etc/app/LOG_LEVEL
```

Change the ConfigMap and wait up to ~60 seconds:

```bash
kubectl patch configmap app-config --type=merge \
  -p '{"data":{"LOG_LEVEL":"debug"}}'
kubectl exec deploy/consumer-file -- cat /etc/app/LOG_LEVEL
# eventually prints "debug"
```

The env-var consumer never sees the change — it would need a pod
restart.

### 5. Secrets

```bash
kubectl create secret generic db-cred \
  --from-literal=username=app \
  --from-literal=password='not-a-real-secret'
kubectl apply -f manifests/consumer-secret.yaml
```

Inspect the Secret's on-disk form with `kubectl get secret db-cred -o yaml`
— note the base64 values. That is the *only* obfuscation you get out of
the box.

## Challenges

### C1. Config-driven podinfo

In namespace `lab-04` deploy two replicas of `podinfo` such that:

- `PODINFO_UI_COLOR` and `PODINFO_UI_MESSAGE` come from a ConfigMap
  named `podinfo-cfg`
- a TLS-like secret `podinfo-creds` with keys `api_key` and `api_secret`
  is mounted at `/etc/podinfo/creds` (read-only)
- the Deployment is labelled `app=podinfo`, pod labels include `app=podinfo`

### C2. Immutable configuration rollout

Create `podinfo-cfg-v2` as a new *immutable* ConfigMap with a different
colour. Update the Deployment to reference `podinfo-cfg-v2` (not
`podinfo-cfg`). The rollout should complete and the verifier should
observe the new colour via the running pods' environment. Do **not**
delete `podinfo-cfg` — the verifier checks both exist.

### C3. Fix a broken reference

Apply `manifests/broken-consumer.yaml`. It references a ConfigMap key
that does not exist and therefore can never start. Fix it by creating
the missing key *without* editing the Deployment manifest or the
Deployment's pod template. The verifier checks the Deployment reaches
Available and its pod template's hash did not change between start and
end.

## Verification

```bash
make verify LAB=04
```

## Further reading

- Kubernetes docs: [*Secrets*](https://kubernetes.io/docs/concepts/configuration/secret/), [*ConfigMaps*](https://kubernetes.io/docs/concepts/configuration/configmap/).
- [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/).
- Anatomy of a rotating Secret, see External Secrets Operator / Bank-Vaults.
