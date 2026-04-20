# Lab 01 — Pods & containers

> **Est. time:** 3 hours.
> **Prereqs:** lab 00.

The Pod is the atom of Kubernetes scheduling. Every other workload
resource (Deployment, StatefulSet, Job, DaemonSet, …) ultimately emits
Pods. Understand pods deeply and the rest of Kubernetes is much easier.

## Learning outcomes

1. Describe the pod lifecycle: `Pending → Running → (Succeeded|Failed)`
   and the intermediate container states.
2. Use `kubectl logs`, `kubectl exec`, and `kubectl debug` to inspect a
   running pod.
3. Write a pod manifest by hand, including resource requests, labels,
   and annotations.
4. Implement the **sidecar**, **init-container**, and **ambassador**
   multi-container patterns.
5. Understand *why* a single pod shares a network namespace and volumes,
   and what that implies for security.

## Background

### Anatomy

A pod is a group of one or more containers that share:

- A network namespace (same IP, same loopback, same port space).
- One or more volumes.
- A lifecycle — the pod is scheduled, and terminated, as a unit.

Containers inside a pod can reach each other on `localhost`, which is
often mistaken as a feature. Treat it as an escape hatch for tightly
coupled helper processes, not as a service-mesh substitute.

### Init containers

`spec.initContainers` run to completion, in order, *before* the main
containers start. They share the pod's volumes but not network-level
state with the main containers while they run. Typical use cases:

- Waiting for a dependency to be reachable.
- Populating a shared volume with assets, seed data, or a TLS bundle.
- Running schema migrations before the app starts.

If an init container fails, the kubelet restarts it according to the
pod's `restartPolicy` and the main containers never start.

### Sidecars

A sidecar is a long-running container that augments the main one — log
shipping, service-mesh proxy, config reloader. In 1.28+, sidecars have a
first-class representation (`initContainers[].restartPolicy: Always`)
that fixes the long-standing lifecycle bug where the main container
would exit before the sidecar drained.

### Ephemeral debug containers

`kubectl debug pod/foo --image=busybox --target=foo` injects a short-lived
container into a running pod, sharing its namespaces so you can run
`ps`, `ss`, `nslookup` against the app without rebuilding its image. The
feature is essential for debugging distroless images.

## Guided walkthrough

Files referenced below live in `manifests/`.

### 1. A pod from YAML

```bash
kubectl apply -f manifests/01-hello-pod.yaml
kubectl get pod hello -o wide
kubectl describe pod hello
```

Read the `Events` at the bottom of the `describe` output. You'll see:

1. `Scheduled` — the scheduler chose a node.
2. `Pulled` — the kubelet pulled the image (or reused it).
3. `Created` — containerd created the container.
4. `Started` — the container is running.

These are the stages you'll be debugging for the rest of your career.

### 2. Observing lifecycle

Introduce a crash and watch the restart backoff:

```bash
kubectl apply -f manifests/02-crash-pod.yaml
kubectl get pod crasher -w
```

You should see `CrashLoopBackOff` appear after a handful of restarts.
The kubelet applies exponential backoff capped at 5 minutes — this is
deliberate; it prevents a broken app from consuming your node.

### 3. Multi-container: sidecar

Apply `manifests/03-sidecar.yaml`. It contains a producer that writes
timestamps into `/data/app.log` and a sidecar running `tail -F` on the
same volume. Inspect each container's output separately:

```bash
kubectl logs writer -c producer
kubectl logs writer -c tailer
```

### 4. Init containers

`manifests/04-init-wait.yaml` runs an init container that `curl`s an
in-cluster service and only exits when it succeeds. Apply it *before*
creating the service it depends on, then watch it block:

```bash
kubectl apply -f manifests/04-init-wait.yaml
kubectl get pod waiter
# STATUS is Init:0/1

kubectl apply -f manifests/04-init-service.yaml
kubectl get pod waiter
# STATUS becomes Running a few seconds later
```

### 5. Debug a pod with no shell

Apply `manifests/05-distroless.yaml` — it uses
`gcr.io/distroless/static-debian12`, which has no shell. `kubectl exec`
fails. Use `kubectl debug` instead:

```bash
kubectl debug -it pod/quiet --image=busybox:1.36 --target=quiet -- sh
# inside the debug container:
ps -ef
nslookup kubernetes.default.svc.cluster.local
```

## Challenges

### C1. A well-labelled pod

Create a pod named `citizen` in the `lab-01` namespace with:

- image `ghcr.io/stefanprodan/podinfo:6.7.0`
- labels `app=citizen`, `tier=frontend`, `lab=01`
- annotation `owner=<your name>`
- resource requests `cpu=50m`, `memory=32Mi`, limits `cpu=200m`,
  `memory=128Mi`
- a readiness probe that HTTP GETs `/readyz` on port 9898

### C2. Init container

Add an init container to `citizen` called `wait-dns` that runs
`busybox:1.36` and does `nslookup kubernetes.default` in a loop until
it succeeds. It should not sleep forever — use a bounded retry.

### C3. Sidecar log shipper

Add a sidecar container to `citizen` called `logger` (image
`busybox:1.36`) that follows the contents of `/var/log/app/access.log`
shared from the main container via an `emptyDir`. The main container
does not actually write to that file — that's fine; the sidecar just
needs to be running.

### C4. A failing pod, deliberately

Create a second pod `failer` that exits with code 137 after 5 seconds
(`sh -c 'sleep 5; exit 137'`) with `restartPolicy: OnFailure`. The
verifier checks that the kubelet is restarting it.

## Verification

```bash
make verify LAB=01
```

## Further reading

- Kubernetes docs: [*Pod lifecycle*](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/).
- Burns & Oppenheimer, [*Design patterns for container-based distributed systems*](https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/45406.pdf).
- KEP-753: [Sidecar Containers](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/753-sidecar-containers).
