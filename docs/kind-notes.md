# Notes on kind

[`kind`](https://kind.sigs.k8s.io) runs a Kubernetes cluster where every
"node" is a Docker container running a real kubelet, containerd, and the
control-plane components. This is close enough to a real cluster that
nearly every lab in this course behaves the same as it would on a managed
platform — with the important exceptions listed below.

## What kind does differently

| Concern | Real cloud | kind |
|---------|-----------|------|
| Node IPs | Routable VPC IPs | Docker bridge IPs, only reachable from the host |
| LoadBalancer services | Cloud LB is provisioned | Stay `<pending>` forever unless you install MetalLB (we do in lab 03) |
| Persistent volumes | CSI driver provisioned disks | Local `hostPath` via the built-in `standard` StorageClass |
| Image pulls | Every node pulls from the registry | You can `kind load docker-image` to push a local image to nodes |
| DNS | External DNS | CoreDNS only; the host's DNS is not visible from pods |

## Pushing a locally-built image

```bash
docker build -t my/app:dev .
kind load docker-image my/app:dev --name k8s-labs
```

Now pods can reference `my/app:dev` with `imagePullPolicy: IfNotPresent`.
Without `kind load`, the kubelet will try to pull from Docker Hub and fail.

## Running a local registry (optional)

Large courses usually want a registry that survives cluster resets:

```bash
docker run -d --restart=always -p 127.0.0.1:5001:5000 --name kind-registry registry:2
docker network connect "kind" kind-registry || true
```

Then tag images as `localhost:5001/my/app:dev` and patch the kind config
to point containerd at the registry. The capstone lab walks you through
this if you want the extra credit.

## Resource hungry?

kind nodes inherit the Docker daemon's CPU and memory limits. On macOS
give Docker Desktop at least 4 CPUs and 6 GiB of RAM in Preferences →
Resources. The graders start to flake below that.

## Cleaning up

```bash
kind delete cluster --name k8s-labs
docker system prune -f            # reclaim disk from old nodes
docker volume prune -f            # reclaim volumes (PVs used hostPath)
```
