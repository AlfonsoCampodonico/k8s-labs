# Lab 12 — Capstone

> **Est. time:** 8 hours.
> **Prereqs:** every preceding lab.

Design, deploy, and operate a non-trivial multi-tier application on
the kind cluster. The capstone is graded manually against the rubric
in [`GRADING.md`](../../GRADING.md); a basic automated verifier
provides a sanity check but is not sufficient for full marks.

## The application

You are deploying a three-tier note-taking service called **scribe**:

```
+-----------+        +------------+        +------------+
|  browser  |  HTTP  |  frontend  |  HTTP  |  backend   |
+-----------+ -----> | (nginx)    | -----> | (podinfo   |
      ^              +------------+        |  serving   |
      |                                    |  JSON)     |
      |                                    +-----+------+
      |                                          |
      |                                          v
      |                                    +------------+
      |                                    |  postgres  |
      |                                    |  (single   |
      |                                    |  replica)  |
      +------------------------------------+------------+
```

You may swap `podinfo` for any HTTP service of your choice and
`postgres` for any stateful workload (Redis, MySQL), provided it's a
real piece of software with real data semantics.

## Requirements

Your submission must include all of the following.

### Architecture (deliverable: `ARCHITECTURE.md`)

- A diagram of the system.
- One paragraph per component: responsibility, failure mode, restart
  story.
- A note on how you would scale each tier horizontally.

### Platform requirements (checked by the verifier)

All in namespace `lab-12`:

1. Three Deployments or workload objects: `frontend`, `backend`,
   `postgres` (a StatefulSet with a headless Service and PVC).
2. Services: `frontend` (ClusterIP), `backend` (ClusterIP), `postgres`
   (headless).
3. One Ingress routing host `scribe.k8s-labs.test` to `frontend`.
4. One Secret `postgres-credentials` with keys `username`, `password`,
   `database` — consumed by `postgres` and `backend`.
5. One ConfigMap used by at least one workload (e.g. `backend-config`
   with feature flags).
6. Resource requests and limits on every container.
7. `readinessProbe` on `frontend` and `backend`.
8. A HorizontalPodAutoscaler targeting `backend` (min 2, max 6, on
   CPU utilisation).
9. Two NetworkPolicies:
   - `default-deny-ingress` selecting every pod.
   - `allow-frontend-to-backend` opening TCP to `backend` from
     `frontend`.
   - (Bonus) `allow-backend-to-postgres` opening TCP to `postgres`
     from `backend` only.
10. Pod Security Admission label on the namespace set to at least
    `baseline`.
11. A Helm chart `charts/scribe/` that renders the whole application.
    `helm install scribe ./charts/scribe -n lab-12` must produce the
    state described above from a clean cluster.

### Operational demo (deliverable: 10-minute screen recording)

Show the grader:

1. A clean `helm install` of your chart.
2. The Ingress working via `curl -H 'Host: scribe.k8s-labs.test' http://localhost:8080/`.
3. A failure scenario and how you debug it (kill a postgres pod, show
   the app recovers; or break a probe and show the rollout failing;
   or exceed a memory limit and observe the OOMKill).
4. A rolling update of `backend` to a new image tag with no downtime
   (use `podinfo` version bump or equivalent).

### Submission

Zip or push a folder with:

```
scribe/
├── ARCHITECTURE.md
├── charts/
│   └── scribe/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── manifests/          # optional — if you also want a non-Helm form
└── recording.mp4
```

Place it in `labs/12-capstone/submission/` for the grader.

## Verification (sanity check)

```bash
make verify LAB=12
```

This checks the required resources exist and are Ready. It does not
award marks on its own — see `GRADING.md`.

## Further reading

- [Realworld microservices benchmarks](https://github.com/GoogleCloudPlatform/microservices-demo) for inspiration.
- Bilgin Ibryam, *Kubernetes Patterns*, 2nd ed.
- Cindy Sridharan, [*Distributed systems observability*](https://www.oreilly.com/library/view/distributed-systems-observability/9781492033431/) — you'll want this for the ops demo.
