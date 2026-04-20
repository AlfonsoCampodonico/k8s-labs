# Lab 03 — Services & Ingress

> **Est. time:** 5 hours.
> **Prereqs:** lab 02.

A Pod's IP is ephemeral and rebuilt on every reschedule. A **Service**
gives a stable virtual IP and DNS name for a set of pods selected by
labels. An **Ingress** routes external HTTP(S) traffic to those
Services. This lab builds both.

## Learning outcomes

1. Reason about the four Service types — ClusterIP, NodePort,
   LoadBalancer, ExternalName — and pick the right one for a scenario.
2. Use headless Services (`clusterIP: None`) for direct pod discovery.
3. Install an Ingress controller (NGINX) on kind and expose an HTTP
   service on `localhost:8080`.
4. Configure host- and path-based routing, including a rewrite rule.
5. Debug broken Services by inspecting `Endpoints` and `EndpointSlice`.

## Background

### How a Service actually works

`kube-proxy` on every node watches the API for Services and
EndpointSlices. When a Service is created it programmes iptables (or
IPVS) rules so traffic destined for the Service's ClusterIP is
DNAT'd to one of the backing pod IPs, chosen with (roughly) round-robin
probability. There is no proxy process in the data path — just kernel
netfilter rules.

### Service types

| Type | Routable from | Use when |
|------|---------------|----------|
| `ClusterIP` (default) | Inside cluster | Pod-to-pod traffic |
| `NodePort` | Cluster + `NodeIP:30000-32767` | Dev/quick test, on-prem ingress of last resort |
| `LoadBalancer` | Cluster + cloud LB | Production ingress on a cloud |
| `ExternalName` | DNS CNAME | Point a cluster DNS name at an external host |

On `kind` there is no cloud LB; `LoadBalancer` services stay `<pending>`
forever unless you install [MetalLB](https://metallb.universe.tf) (we
do in challenge C4).

### Headless Services

Setting `spec.clusterIP: None` tells kube-proxy not to allocate a VIP.
DNS returns the pod IPs directly (one A record per endpoint). This is
how StatefulSets expose per-pod DNS (`pod-0.web.default.svc.cluster.local`).

### Ingress

The Ingress API is a thin spec; the actual HTTP routing is implemented
by an ingress controller (NGINX, Traefik, HAProxy, Istio, …). On this
course we use the official [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
because kind has a tailored deployment for it.

## Guided walkthrough

### 1. ClusterIP + DNS

```bash
kubectl apply -f manifests/echo.yaml              # Deployment + ClusterIP svc
kubectl get svc,endpointslices -l app=echo
kubectl run shell --rm -it --image=busybox:1.36 -- sh
# inside the pod:
nslookup echo.default.svc.cluster.local
wget -qO- echo.default/      # ClusterIP works by name
```

### 2. NodePort

```bash
kubectl apply -f manifests/echo-nodeport.yaml
kubectl get svc echo-np
# from the host (kind maps control-plane node to 127.0.0.1):
curl http://127.0.0.1:$(kubectl get svc echo-np -o jsonpath='{.spec.ports[0].nodePort}')
```

### 3. Install NGINX Ingress

```bash
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl -n ingress-nginx wait --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=180s
```

The kind config mapped the control-plane node's ports 80/443 to the
host's 8080/8443, so once the controller is up you can browse to
`http://localhost:8080`.

### 4. An Ingress

```bash
kubectl apply -f manifests/echo-ingress.yaml
curl -H 'Host: echo.k8s-labs.test' http://localhost:8080/
```

## Challenges

### C1. Service for a two-track deployment

Use the `web` and `web-canary` Deployments from lab 02. In namespace
`lab-03`, create:

- a ClusterIP Service `web` that selects both tracks (both stable and
  canary pods in the endpoint pool) on port 80 → pod port 9898
- a *headless* Service `web-stable` that selects only `track=stable`
- a headless Service `web-canary` that selects only `track=canary`

Re-deploy the two Deployments into `lab-03` if you need to — the
solutions directory has manifests you can adapt.

### C2. Ingress with host & path routing

Create an Ingress named `web-ingress` in `lab-03` that:

- terminates at host `web.k8s-labs.test`
- routes `/` to service `web` on port 80
- routes `/canary` to service `web-canary` on port 80, rewriting the
  path to `/`
- uses `ingressClassName: nginx`

Verify with:

```bash
curl -H 'Host: web.k8s-labs.test' http://localhost:8080/
curl -H 'Host: web.k8s-labs.test' http://localhost:8080/canary
```

### C3. A broken Service to fix

Apply `manifests/broken-service.yaml`. Its endpoints list is empty
because a label selector has a typo. Fix it *without* deleting and
recreating the Service. The verifier checks that the Service has at
least one endpoint and the original Service object was not deleted
(its UID must not have changed).

### C4 (optional). LoadBalancer via MetalLB

Install MetalLB in L2 mode, configure it to hand out addresses from the
kind Docker network, then switch the `web` Service to
`type: LoadBalancer` and hit it from the host. Marked as bonus.

## Verification

```bash
make verify LAB=03
```

## Further reading

- Tim Hockin, [*Kubernetes Services: Deep Dive*](https://www.youtube.com/watch?v=NFApeJRXos4).
- [EndpointSlice API reference](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/).
- Ingress-NGINX [canary routing annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#canary).
