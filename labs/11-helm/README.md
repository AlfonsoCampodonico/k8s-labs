# Lab 11 — Helm

> **Est. time:** 4 hours.
> **Prereqs:** labs 02, 03, 04.

Helm packages Kubernetes manifests into **charts**. A chart is a
directory of Go-templated YAML plus a `values.yaml` of defaults. You
install a chart to produce a **release** — a named deployment of the
chart into a specific cluster/namespace. Releases are versioned so
you can roll back.

## Learning outcomes

1. Install a public chart, override values, upgrade, and roll back.
2. Inspect a rendered chart with `helm template`.
3. Author a chart from scratch with a Deployment, Service, and
   conditional Ingress.
4. Understand the difference between `helm template`, `helm install`,
   and `kubectl apply` — and when Helm is the wrong answer.

## Background

### What Helm actually does

1. `helm install` renders the chart templates with your values + a
   built-in `Release.*` context.
2. It posts every rendered resource to the cluster via the API, and
   stores a *release manifest* as a Secret (or ConfigMap) in the
   namespace.
3. `helm upgrade` diffs the new rendered set against the stored
   manifest, applies the delta, and stores a new release revision.
4. `helm rollback` rolls the cluster back to a previous stored
   manifest.

If you only ever need rendered YAML, `helm template ... | kubectl apply -f -`
is a legitimate alternative — at the cost of losing the rollback story.

## Guided walkthrough

### 1. Install a public chart

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install demo bitnami/nginx -n lab-11 --create-namespace \
  --set service.type=ClusterIP --set replicaCount=2
helm list -n lab-11
kubectl -n lab-11 get all
```

### 2. Upgrade and roll back

```bash
helm upgrade demo bitnami/nginx -n lab-11 --set replicaCount=3 --reuse-values
helm history demo -n lab-11
helm rollback demo 1 -n lab-11
```

### 3. Render without applying

```bash
helm template demo bitnami/nginx --set replicaCount=3 | less
```

### 4. Your own chart

Skeleton chart in `solutions/podinfo/`. Inspect it:

```bash
helm template solutions/podinfo --set replicaCount=2 --set image.tag=6.7.1
helm install myapp solutions/podinfo -n lab-11 --set image.tag=6.7.1
```

## Challenges

### C1. A release from a public chart

Install Bitnami NGINX into `lab-11` as release name `demo` with
`replicaCount=2`, `service.type=ClusterIP`. The verifier reads the
helm release metadata.

### C2. Author a chart

In `labs/11-helm/charts/podinfo/` (you create it) produce a chart for
podinfo with:

- `Chart.yaml` with `apiVersion: v2`, `name: podinfo`, `version: 0.1.0`,
  `appVersion: "6.7.1"`
- `values.yaml` exposing at least `replicaCount`, `image.repository`,
  `image.tag`, `service.port`, `ingress.enabled`, `ingress.host`
- templates: `deployment.yaml`, `service.yaml`, and
  `ingress.yaml` guarded by `{{- if .Values.ingress.enabled }}`
- A `_helpers.tpl` file with a `podinfo.labels` template used on
  every resource

Install as release `myapp` in `lab-11` with `replicaCount=2`,
`image.tag=6.7.1`, `ingress.enabled=false`.

## Verification

```bash
make verify LAB=11
```

## Further reading

- [Helm docs](https://helm.sh/docs/).
- [*Helm Chart Best Practices*](https://helm.sh/docs/chart_best_practices/).
- Daniel Bryant & Nicola Jennings, [*Expose anti-patterns in Helm charts*](https://www.cncf.io/blog/?s=helm+anti-pattern).
