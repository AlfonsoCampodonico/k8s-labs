# Lab 00 — Bootstrap

> **Est. time:** 1 hour.
> **Prereqs:** none — this is where you start.

This lab is a warm-up. By the end of it you will have a working kind
cluster, a functioning `kubectl`, and a basic mental model of what just
happened. You'll also meet the automated grader you'll use for the rest of
the course.

## Learning outcomes

After this lab you can:

1. Install and verify the tooling required by the course.
2. Create and destroy a multi-node Kubernetes cluster on your laptop.
3. List the control-plane components and explain the role of each one.
4. Switch between namespaces and contexts with `kubectl`.
5. Read a resource from the cluster three different ways (`get`,
   `describe`, `get -o yaml`).

## Background

### What is Kubernetes, actually?

Kubernetes is a control loop. You write down what you want ("three copies
of this container, always"), and the system's controllers continuously
observe the cluster and take action to reduce the delta between the
*declared state* (what you wrote) and the *actual state* (what's running).
Nothing else — no queues, no workflow engine — just hundreds of small
loops reading and writing to a shared datastore.

The shared datastore is **etcd**. The only process that talks to etcd
directly is the **kube-apiserver**. Everything else — controllers, the
scheduler, your `kubectl` — talks to the API server over HTTPS. That makes
the API server the one thing you truly cannot lose.

### What is kind?

[`kind`](https://kind.sigs.k8s.io) packages Kubernetes into Docker
containers. Each "node" is a container running a real kubelet,
containerd, and (on control-plane nodes) the API server, scheduler, and
controller-manager. From *inside* the cluster it looks exactly like a
real cluster. The caveats live in [`docs/kind-notes.md`](../../docs/kind-notes.md)
— skim that file now.

## Guided walkthrough

### 1. Preflight

```bash
./bin/preflight.sh
```

Every line should start with `PASS`. If not, install the missing tool and
re-run.

### 2. Create the cluster

```bash
make cluster
```

This runs `kind create cluster --config clusters/kind-basic.yaml`. Look at
that file — it describes one control-plane and two worker nodes, and asks
kind to label the control-plane node so an Ingress controller can bind to
ports 80/443. When the command finishes you should see:

```text
Nodes:
NAME                       STATUS   ROLES           AGE   VERSION
k8s-labs-control-plane     Ready    control-plane   30s   v1.29.x
k8s-labs-worker            Ready    <none>          20s   v1.29.x
k8s-labs-worker2           Ready    <none>          20s   v1.29.x
```

### 3. Meet the control plane

Control-plane components run as static pods in the `kube-system`
namespace:

```bash
kubectl -n kube-system get pods
```

Spend a minute mapping what you see:

- `etcd-k8s-labs-control-plane` — the key/value store.
- `kube-apiserver-k8s-labs-control-plane` — the only thing that talks to
  etcd. Every other component talks to it.
- `kube-controller-manager-...` — a single binary hosting dozens of
  controllers (Deployment, ReplicaSet, Node, Namespace, …).
- `kube-scheduler-...` — assigns pending pods to nodes.
- `kindnet-...` — the CNI plugin that gives pods IP addresses.
- `coredns-...` — in-cluster DNS.
- `kube-proxy-...` — programs node iptables/ipvs for Services.

Run `kubectl -n kube-system describe pod kube-apiserver-k8s-labs-control-plane`
and read the args. Everything important about your cluster — admission
plugins, feature gates, encryption — is encoded there.

### 4. Namespaces and contexts

A *context* is a (cluster, user, namespace) tuple in your kubeconfig.
A *namespace* scopes resources inside a cluster.

```bash
kubectl config current-context          # prints kind-k8s-labs
kubectl get namespaces

kubectl create namespace lab-00
kubectl config set-context --current --namespace=lab-00
kubectl get all                         # empty, you're in lab-00 now
```

You can always switch back to `default` with the same command.

### 5. Your first pod, three ways

Create a pod with the imperative command:

```bash
kubectl run hello --image=nginx:1.27-alpine
```

Inspect it three ways. Notice what each view emphasises:

```bash
kubectl get pod hello                   # one-line summary
kubectl describe pod hello              # human-readable, includes Events
kubectl get pod hello -o yaml           # full declarative manifest
```

Clean up when you've read the YAML:

```bash
kubectl delete pod hello
```

## Challenges

Complete all three before running the verifier.

### C1. Two namespaces

Create two namespaces, `lab-00-alpha` and `lab-00-beta`, each labelled
with `lab=bootstrap`. The verifier checks the labels, not just the
existence.

### C2. A pod in each namespace

Create an nginx pod named `sentinel` in each of the two namespaces. Use
the official `nginx:1.27-alpine` image. The pods must reach the `Running`
phase and be `Ready`.

### C3. A kubeconfig habit

Set your current context's default namespace to `lab-00-alpha`. The
verifier reads your kubeconfig to check this.

A reference solution is in [`solutions/`](solutions/), but don't open it
until you've tried the challenges.

## Verification

```bash
make verify LAB=00
```

Every line should begin with `PASS`. Any `FAIL` explains what it expected
and what it saw.

## Further reading

- Official concepts: [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/).
- Brendan Burns, [*Designing Distributed Systems*, chapter 1](https://azure.microsoft.com/en-us/resources/designing-distributed-systems/).
- [Kubernetes the Hard Way](https://github.com/kelsey-hightower/kubernetes-the-hard-way) — once you are comfortable, this is the next mountain.
