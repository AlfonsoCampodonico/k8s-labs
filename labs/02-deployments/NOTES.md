# Lab 02 — instructor notes

## Discussion prompts

- Why does the Deployment controller keep old ReplicaSets with zero
  replicas? (So `kubectl rollout undo` is O(1). The storage cost is
  trivial.)
- A student argues that `maxUnavailable: 0` is always the right
  choice. Push back: it doubles the worst-case resource footprint
  during rollout, which is expensive for large Deployments.
- What happens during a rollout if a pod's readiness probe briefly
  flaps? (`progressDeadlineSeconds` — default 600 — kicks in and fails
  the rollout. Worth showing.)

## Mark scheme

12 checks, 1 mark each, cap at 10.
