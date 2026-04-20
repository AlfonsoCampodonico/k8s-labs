# Lab 11 — instructor notes

## Discussion prompts

- When is Helm the *wrong* tool? (Anywhere you need a real Kubernetes
  operator — reconciling state, reacting to resource events.
  Kustomize is often a better fit for pure overlays.)
- Why are Helm hooks a footgun? (They run outside the normal rollout
  semantics; timing bugs are easy.)

## Mark scheme

6 checks, cap at 6.
