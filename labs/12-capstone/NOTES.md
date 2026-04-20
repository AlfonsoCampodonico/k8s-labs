# Lab 12 — instructor notes

The verifier is intentionally coarse; use `GRADING.md` for marks.

## Failure injections the grader can run during the demo

1. `kubectl -n lab-12 delete pod postgres-0` — the StatefulSet should
   re-create it; the backend should become Ready again.
2. `kubectl -n lab-12 patch deploy backend --type=merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","image":"ghcr.io/stefanprodan/podinfo:does-not-exist"}]}}}}'` — the rollout should stall, not cascade into outage.
3. Apply a NetworkPolicy deleting the backend allow — the frontend
   should degrade gracefully.

## Red flags

- `latest` tags anywhere.
- Secrets baked into ConfigMaps.
- cluster-admin RoleBindings.
- No liveness/readiness probes.
- HPA targeting memory without reasoning.

## Top-marks submissions historically do the following

- Use a non-trivial signed-request pattern between frontend and
  backend to justify an explicit NetworkPolicy.
- Document the RTO/RPO for postgres and demonstrate backup/restore.
- Include a PodDisruptionBudget for `backend`.
