# Grading rubric

Every module ships an automated verifier (`labs/NN-topic/verify.sh`) that
inspects the live cluster and prints a deterministic score. The verifier is
the source of truth for the graded portion of each lab.

## How the grader works

- It assumes the current kubeconfig context points at the kind cluster
  created by `make cluster`.
- It does **not** inspect your `solutions/` directory — it only looks at
  resources present in the cluster.
- Every check is idempotent and printed with a `PASS` or `FAIL` prefix so
  partial credit is unambiguous.
- Exit code `0` means every check passed. A non-zero exit code indicates how
  many checks failed.

## Running the grader

Single lab:

```bash
make verify LAB=03
```

All labs at once (instructor view):

```bash
./bin/grade.sh > report.md
```

The report looks like:

```
# k8s-labs grading report
Generated: 2026-04-20T14:02:11Z
Cluster:   kind-k8s-labs

| Lab | Score | Status |
|-----|:-----:|--------|
| 00  | 5/5   | PASS   |
| 01  | 7/8   | FAIL   |
...
```

## Capstone rubric (Lab 12)

The capstone is graded manually. Marks are allocated as follows:

| Criterion | Weight | Description |
|-----------|:-----:|-------------|
| Design document | 20% | Architecture diagram, component responsibilities, scaling & failure story |
| Correctness | 25% | All services run, persistent data survives pod restarts, ingress routes to the right places |
| Observability | 15% | Useful logs, events, probes; the student can diagnose a failure injected by the grader |
| Security | 15% | RBAC is least-privilege; NetworkPolicies are default-deny with explicit allows; no secrets in plain manifests |
| Operations | 15% | HPA configured and justified, resource requests match observed usage, rollout strategy is documented |
| Code quality | 10% | Manifests are organised, commented where non-obvious, and pass `kubeval` / `kubectl diff --server-side` cleanly |

## Academic integrity

The `solutions/` directory of every lab contains a reference implementation.
It is there so instructors can grade quickly and students can compare
*after* they finish. Submitting the reference solution verbatim is a breach
of academic integrity — the verifier does not detect this, but the
instructor's reading of the accompanying design notes will.
