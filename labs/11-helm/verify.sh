#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 11 — helm"

ns="lab-11"
assert_resource namespace "${ns}" ""

if ! command -v helm >/dev/null 2>&1; then
  fail "helm is not installed"
  summary
fi

# C1 — demo release exists.
if helm list -n "${ns}" -q 2>/dev/null | grep -qx demo; then
  pass "helm release 'demo' exists in ${ns}"
  chart=$(helm list -n "${ns}" -o json | jq -r '.[] | select(.name=="demo").chart')
  if [[ "${chart}" == nginx-* ]]; then
    pass "demo release uses an nginx chart (${chart})"
  else
    fail "demo release chart should start with 'nginx-' (got: ${chart:-<none>})"
  fi
else
  fail "helm release 'demo' missing in ${ns}"
fi

# C2 — myapp release (student's chart).
if helm list -n "${ns}" -q 2>/dev/null | grep -qx myapp; then
  pass "helm release 'myapp' exists in ${ns}"
  chart=$(helm list -n "${ns}" -o json | jq -r '.[] | select(.name=="myapp").chart')
  if [[ "${chart}" == podinfo-* ]]; then
    pass "myapp uses a podinfo chart (${chart})"
  else
    fail "myapp chart should start with 'podinfo-' (got: ${chart:-<none>})"
  fi
  # Pods are Ready.
  if kubectl -n "${ns}" get deploy -l app.kubernetes.io/instance=myapp >/dev/null 2>&1; then
    ready=$(kubectl -n "${ns}" get deploy -l app.kubernetes.io/instance=myapp \
      -o jsonpath='{.items[*].status.readyReplicas}' | tr ' ' '+' | bc 2>/dev/null || echo 0)
    if [[ "${ready:-0}" -ge 1 ]]; then
      pass "myapp has ${ready} ready replica(s)"
    else
      fail "myapp has no ready replicas"
    fi
  fi
else
  fail "helm release 'myapp' missing — did you install your podinfo chart?"
fi

summary
