# Lab 10 — Observability & debugging

> **Est. time:** 4 hours.
> **Prereqs:** labs 01 and 08.

Production clusters fail in creative ways. Reading logs, events, and
metrics is not optional; neither is having a disciplined triage
routine. This lab builds that routine.

## Learning outcomes

1. Use `kubectl describe`, `kubectl events`, and `kubectl logs` in a
   principled order to triage a failing pod.
2. Use `kubectl debug` to attach an ephemeral container to a pod, a
   node, or a pod copy with extra tools.
3. Read cluster metrics from `metrics.k8s.io` and `kubectl top`.
4. Articulate a one-page "triage playbook" you can use when on-call.

## Background

### The triage order that works

1. `kubectl get pod -o wide` — what's the phase? what node?
2. `kubectl describe pod` — what do the Events say? *Do not skip this*.
3. `kubectl logs --previous` — what did the last container say before
   it died?
4. `kubectl get events --sort-by=.lastTimestamp` — cluster-wide events
   in time order. Often a nearby event is the cause.
5. `kubectl top pods` — CPU/memory pressure visible here.
6. `kubectl debug` — when you need tools the image doesn't ship.

### Ephemeral containers

`kubectl debug pod/foo -it --image=busybox:1.36 --target=foo` adds a
container to the pod that shares the target's namespaces. Use `--image=nicolaka/netshoot`
for the full network-debugging kit. Use `--copy-to=foo-debug --share-processes`
to debug a *copy* of the pod (non-destructive; the original keeps
running).

Node-scope debugging is similar: `kubectl debug node/<node>` drops you
onto a pod with the node's root filesystem mounted at `/host`.

## Guided walkthrough

### 1. Install metrics-server (re-uses lab 08's manifest)

```bash
kubectl apply -f ../08-health-resources/manifests/metrics-server.yaml
```

### 2. Triage a broken pod

```bash
kubectl apply -f manifests/broken-pod.yaml
kubectl get pod broken
kubectl describe pod broken
kubectl logs pod/broken --previous
kubectl get events --sort-by=.lastTimestamp | tail -n 20
```

Read each output carefully; the bug is discoverable from `describe`
alone.

### 3. `kubectl debug` a distroless pod

```bash
kubectl apply -f manifests/distroless-pod.yaml
kubectl debug -it pod/distroless --image=nicolaka/netshoot --target=app -- bash
# inside:
nslookup kubernetes.default
ss -tnp
```

### 4. Node-level shell

```bash
kubectl debug node/k8s-labs-worker --image=busybox:1.36 -it -- chroot /host
# you're now root in the kind node container
```

## Challenges

### C1. Fix this pod

Apply `manifests/challenge-broken.yaml`. It is broken in three
compounding ways: wrong image tag, missing ConfigMap key referenced by
an env, and a liveness probe that fires before the app is ready. Fix
all three *without* deleting the pod. The verifier checks the pod
eventually reaches Running+Ready and the Deployment's
`observedGeneration >= 3` (three applies).

### C2. Write a triage playbook

Create a ConfigMap named `triage-playbook` in `lab-10` with key
`playbook.md` whose content is your own 1-page, numbered checklist for
responding to an alert "pod is CrashLoopBackOff". The verifier only
checks the object exists and its key is non-empty — the instructor
grades the content.

### C3. Metrics

Install metrics-server (if not already) and run
`kubectl top pods -n lab-10`. The verifier checks that
`metrics.k8s.io` is available and at least one pod reports usage.

## Verification

```bash
make verify LAB=10
```

## Further reading

- Kubernetes docs: [*Debugging pods*](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/).
- Netshoot — [kubernetes-sigs/netshoot](https://github.com/nicolaka/netshoot).
- Brendan Gregg, [*Systems Performance*](https://www.brendangregg.com/systems-performance-2nd-edition-book.html) — chapter 2 especially.
