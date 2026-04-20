# Triage playbook — pod in CrashLoopBackOff

1. `kubectl -n <ns> get pod <p> -o wide` — note phase, node, restarts.
2. `kubectl -n <ns> describe pod <p>` — read the Events list bottom-up.
   The cause is almost always there.
3. `kubectl -n <ns> logs <p> --previous` — the dying container's last
   words.
4. Classify:
   - `ImagePullBackOff` → image/tag wrong, registry unauthorised, node
     can't reach registry.
   - `CreateContainerConfigError` → a ConfigMap/Secret referenced by
     env/volume is missing.
   - `CrashLoopBackOff` with exit 0 → liveness killed it, not the app.
   - `CrashLoopBackOff` with exit 137 → OOMKilled; check memory limits.
   - `CrashLoopBackOff` with exit 1/139 → app bug; logs will say why.
5. Cross-check `kubectl get events --sort-by=.lastTimestamp -n <ns>`.
6. If needed, `kubectl debug pod/<p> -it --image=nicolaka/netshoot --target=<c>`.
7. Fix the root cause, re-apply, and watch `kubectl rollout status`.
