# Syllabus

A thirteen-module curriculum designed for a one-semester upper-division
course, roughly 3–6 hours of work per module. Labs are independent; later
modules do not assume you kept clusters or manifests from earlier ones.

## Learning outcomes (course-level)

By the end of the course a student can:

1. Explain the Kubernetes architecture — control plane, nodes, API server,
   etcd, scheduler, controllers, kubelet, kube-proxy — and trace what happens
   between `kubectl apply` and a running container.
2. Design and deploy multi-tier, stateful workloads using idiomatic
   primitives (Deployments, StatefulSets, Services, Ingress, PVCs).
3. Apply production concerns — configuration, secrets, resource limits,
   probes, RBAC, NetworkPolicies, autoscaling, observability — to a
   non-trivial application.
4. Debug a broken cluster using `kubectl`, events, logs, and the Kubernetes
   API, and articulate a hypothesis-driven troubleshooting process.
5. Read and write Helm charts and understand when templating vs. rendering
   vs. generating YAML is the right tool.

## Module breakdown

| # | Module | Outcomes | Est. time | Weight |
|---|--------|----------|-----------|:-----:|
| 00 | Bootstrap | Install tooling, create/destroy kind clusters, understand kubeconfig contexts, inspect cluster components | 1h | 2% |
| 01 | Pods & containers | Build, inspect, and debug pods; multi-container patterns (sidecars, init); container image anatomy | 3h | 6% |
| 02 | Deployments | ReplicaSet vs. Deployment, rolling updates, rollbacks, deployment strategies | 4h | 8% |
| 03 | Services & Ingress | Service types, DNS, endpoints, Ingress controllers, path/host routing | 5h | 10% |
| 04 | ConfigMaps & Secrets | Configuration injection, reload semantics, secret volume vs. env, immutable config | 3h | 6% |
| 05 | Storage | Volumes, PV/PVC binding, access modes, StorageClasses, dynamic provisioning, retention | 4h | 8% |
| 06 | StatefulSets | Stable identity, headless services, PVC templates, ordered rollout, a 3-node clustered app | 5h | 10% |
| 07 | Jobs & CronJobs | Parallelism, completions, restart policies, CronJob schedules, failure handling | 3h | 6% |
| 08 | Health, resources, autoscaling | Liveness/readiness/startup probes, requests/limits, QoS classes, HorizontalPodAutoscaler, metrics-server | 4h | 8% |
| 09 | RBAC & security | ServiceAccounts, Roles, RoleBindings, aggregated roles, NetworkPolicies, Pod Security Admission | 5h | 10% |
| 10 | Observability & debugging | Events, logs, `kubectl debug`, ephemeral containers, metrics-server queries, cluster triage playbook | 4h | 8% |
| 11 | Helm | Anatomy of a chart, values, templating, releases, hooks, basic chart authoring | 4h | 8% |
| 12 | Capstone | Design and deploy a four-service application with persistent state, ingress, autoscaling, and network policies | 8h | 10% |

Total: ~53 hours of directed work.

## Assessment

- **Automated grading**: Each module ships a `verify.sh` that inspects the
  live cluster against an explicit rubric and prints a score. The instructor
  collects these scores with `bin/grade.sh`.
- **Challenges**: Every module ends with at least one open-ended challenge
  that the verifier checks. Solutions must work against a fresh cluster.
- **Capstone**: Graded manually against the rubric in
  [`GRADING.md`](GRADING.md). Students submit a short design document, the
  manifests, and a ~10-minute screen recording demoing the system.

## Recommended reading

- Kelsey Hightower, *Kubernetes the Hard Way*.
- Burns, Beda, Hightower, *Kubernetes: Up & Running* (3rd ed.).
- The official [Kubernetes Documentation](https://kubernetes.io/docs/) — the
  primary reference throughout.
- KubeCon conference talks are linked from each module's *Further reading*
  section where relevant.
