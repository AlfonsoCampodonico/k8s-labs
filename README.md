# k8s-labs

A university-grade, self-paced course for learning Kubernetes on your laptop.
Clusters are built with [kind](https://kind.sigs.k8s.io) (Kubernetes in Docker),
so the whole curriculum runs locally with no cloud account required.

The course is organised as thirteen modules, each one a self-contained lab with
theory, guided exercises, open-ended challenges, and an automated verifier that
produces a pass/fail grade. A student who finishes every module should be able
to operate a non-trivial cluster, reason about Kubernetes primitives from first
principles, and debug problems with confidence.

## Who this is for

- Upper-division undergraduates or master's students in a cloud / distributed
  systems course.
- Self-taught engineers preparing for the CKA / CKAD certifications.
- Instructors who want a batteries-included curriculum they can fork and
  customise.

## Prerequisites

You need a laptop (macOS, Linux, or WSL2) with at least 4 CPU cores and 8 GiB
of RAM free, plus:

| Tool | Min version | Purpose |
|------|-------------|---------|
| [Docker](https://docs.docker.com/get-docker/) or [Podman](https://podman.io) | 24.x | Container runtime for kind nodes |
| [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) | 0.22 | Local Kubernetes cluster |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | 1.29 | Kubernetes CLI |
| [helm](https://helm.sh) | 3.14 | Package manager (module 11) |
| `bash`, `jq`, `curl` | recent | Used by the verifiers |

Run `./bin/preflight.sh` to check your environment.

## Quick start

```bash
git clone <this repo>
cd k8s-labs

./bin/preflight.sh          # verify tooling
make cluster                # create the default kind cluster
make lab LAB=01             # open the lab 01 worktree
make verify LAB=01          # run the automated grader for lab 01
make cluster-down           # tear the cluster down when you are done
```

Every lab is independent. You can work through them in order (recommended) or
jump straight to a topic you want to revise.

## Curriculum at a glance

| # | Module | Core concepts |
|---|--------|---------------|
| 00 | [Bootstrap](labs/00-bootstrap/README.md) | kind, kubeconfig, kubectl plumbing |
| 01 | [Pods & containers](labs/01-pods/README.md) | Pod lifecycle, multi-container pods, ephemeral debug |
| 02 | [Deployments & ReplicaSets](labs/02-deployments/README.md) | Declarative workloads, rolling updates, rollbacks |
| 03 | [Services & Ingress](labs/03-services-ingress/README.md) | ClusterIP/NodePort/LoadBalancer, Ingress, DNS |
| 04 | [ConfigMaps & Secrets](labs/04-config-secrets/README.md) | Configuration patterns, env vs. volume, immutability |
| 05 | [Storage](labs/05-storage/README.md) | Volumes, PV/PVC, StorageClasses, dynamic provisioning |
| 06 | [StatefulSets](labs/06-statefulsets/README.md) | Stable identity, ordered rollout, headless services |
| 07 | [Jobs & CronJobs](labs/07-jobs/README.md) | Batch workloads, parallelism, scheduled jobs |
| 08 | [Health, resources, autoscaling](labs/08-health-resources/README.md) | Probes, requests/limits, HPA, QoS classes |
| 09 | [RBAC & security](labs/09-rbac-security/README.md) | ServiceAccounts, Roles, NetworkPolicies, PSA |
| 10 | [Observability & debugging](labs/10-observability/README.md) | `kubectl debug`, metrics-server, logs, events |
| 11 | [Helm](labs/11-helm/README.md) | Charts, values, releases, templating |
| 12 | [Capstone](labs/12-capstone/README.md) | Design, deploy, and operate a multi-tier app |

Full learning outcomes, time estimates, and weighting are in
[`SYLLABUS.md`](SYLLABUS.md). The rubric used by the graders is in
[`GRADING.md`](GRADING.md).

## Repository layout

```
.
├── bin/            # preflight, cluster lifecycle, grader
├── clusters/       # kind cluster topologies
├── docs/           # cheatsheets & reference material
├── labs/NN-topic/  # one directory per module
│   ├── README.md       # theory + tasks
│   ├── manifests/      # starter YAML
│   ├── solutions/      # reference solutions (try not to peek!)
│   ├── verify.sh       # automated grader
│   └── NOTES.md        # instructor notes / answer key
├── lib/            # shared shell helpers used by verifiers
├── Makefile        # top-level entry point
└── SYLLABUS.md
```

## Working on a lab

Each lab's `README.md` is structured the same way:

1. **Learning outcomes** — what you will be able to do after finishing.
2. **Background** — the theory you need, written to be read, not skimmed.
3. **Guided walkthrough** — step-by-step exercises that build intuition.
4. **Challenges** — open-ended tasks you solve on your own.
5. **Verification** — `./verify.sh` checks the cluster against an explicit
   rubric and prints a score.
6. **Further reading** — canonical references.

Solutions live in `solutions/` but the verifier does not look at them — it
inspects the live cluster. You can submit any implementation you like.

## Instructor use

- `bin/grade.sh` runs every lab verifier and emits a Markdown report.
- `NOTES.md` in each lab contains discussion prompts and a mark scheme.
- Labs are independent enough to be assigned out of order or in parallel.
- The `kind` topology is pinned in `clusters/kind-basic.yaml` so every student
  sees the same versions and node counts.

## License

MIT. See [`LICENSE`](LICENSE).
