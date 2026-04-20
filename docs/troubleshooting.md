# Troubleshooting

A short field guide for the most common failures students hit in the labs.
When `./verify.sh` prints a FAIL, work down this list before asking for help.

## "connection refused" on `kubectl get nodes`

- Is the Docker daemon running? `docker info`
- Does the cluster still exist? `kind get clusters`
- Is the kubeconfig context right? `kubectl config current-context`
  should print `kind-k8s-labs`.
- Sometimes a laptop sleep/resume leaves the API server's TLS cert stale;
  `make reset` is the brute-force fix.

## Pod stuck in `Pending`

Run `kubectl describe pod <name>` and read the Events. Common causes:

| Event | Meaning | Fix |
|-------|---------|-----|
| `0/3 nodes available: insufficient cpu/memory` | Resource requests exceed cluster capacity | Lower `requests`, or allocate more RAM to Docker |
| `pod has unbound immediate PersistentVolumeClaims` | PVC hasn't bound to a PV yet | Check the StorageClass; the default provisioner may not exist |
| `0/3 nodes are available: node(s) didn't match Pod's node affinity/selector` | `nodeSelector` / `affinity` matches nothing | Remove the selector or re-label the node |
| `CreateContainerConfigError` | Usually a ConfigMap/Secret reference that doesn't exist | `kubectl describe` shows the exact missing key |

## Pod stuck in `CrashLoopBackOff`

- `kubectl logs <pod>` — what does the app print?
- `kubectl logs <pod> --previous` — the crashed container's last output.
- `kubectl describe pod <pod>` — exit code (137 = OOM, 139 = segfault).
- Readiness vs. liveness: a misconfigured liveness probe will kill a healthy
  app. Temporarily remove the probe and re-deploy to isolate.

## Service has no endpoints

`kubectl get endpoints <svc>` is empty.

- The Service's `selector` and the Pod labels must match **exactly**. Typos
  in label keys are silent.
- Pods must be Ready (their readiness probes must pass) before they appear
  in the endpoints list.
- If you used `type: ExternalName`, there are no endpoints by design.

## Ingress returns 404 / 503

- Is the ingress controller running? `kubectl -n ingress-nginx get pods`
- Did you create an `IngressClass` and reference it? `ingressClassName:`
  is required in modern Kubernetes.
- Paths are regexes in NGINX Ingress — use `pathType: Prefix` for plain
  string matches.
- `kubectl -n ingress-nginx logs deploy/ingress-nginx-controller` has the
  actual HTTP access log.

## `kind load docker-image` is slow

`kind` tars the image and streams it into every node. Large images take
a while. Use `--nodes control-plane` to load onto a single node, or push
to a local registry instead (see `docs/kind-notes.md`).

## "x509: certificate signed by unknown authority"

Usually caused by Docker Desktop swapping its internal certificate on a
version upgrade. `make reset` will fix it.

## Nothing else works

```bash
make cluster-down
docker system prune -f          # reclaim space from dead kind nodes
make cluster
```

Most problems evaporate with a clean cluster. Don't spend more than 15
minutes fighting a broken kind install — the reproducible setup is the
whole point.
