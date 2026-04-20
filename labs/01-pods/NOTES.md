# Lab 01 — instructor notes

## Discussion prompts

- Why do containers inside a pod share a network namespace but *not* a
  PID namespace by default? (Security: one container process should not
  see another's processes unless explicitly opted in via
  `shareProcessNamespace: true`.)
- If a sidecar you wrote crashes, should the pod be considered
  unhealthy? (Depends. Pre-1.28 it was invisible to the Service; with
  the native sidecar feature it's a proper restart loop and the pod is
  Not Ready until the sidecar recovers.)
- What's wrong with putting both an app and a database in the same pod?
  (Independent scaling, independent lifecycle, independent resource
  accounting — the pod model says "co-scheduled", not "coupled".)

## Observations while teaching

- Students reliably get the init-container YAML indentation wrong.
  Demo `kubectl explain pod.spec.initContainers` to reinforce that
  `kubectl explain` is faster than googling.
- Don't be afraid to spend 20 minutes on `kubectl describe`. The Events
  section is where students learn to debug.

## Mark scheme

`verify.sh` has 12 checks worth 1 mark each. Cap at 10 to leave 2 marks
for the discussion question on the next written quiz.
