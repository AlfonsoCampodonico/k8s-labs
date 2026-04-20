#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 10 — observability"

ns="lab-10"
assert_resource namespace "${ns}" ""

# C1 — broken deployment fixed.
if kubectl -n "${ns}" get deploy broken >/dev/null 2>&1; then
  pass "deployment/broken exists"
  assert_pods_ready "app=broken" "${ns}" 1
  img=$(kubectl -n "${ns}" get deploy broken -o jsonpath='{.spec.template.spec.containers[0].image}')
  if [[ "${img}" == ghcr.io/stefanprodan/podinfo:* ]] && [[ "${img}" != *does-not-exist ]]; then
    pass "broken image points at a valid podinfo tag (${img})"
  else
    fail "broken image should be a real podinfo tag (got: ${img})"
  fi
  gen=$(kubectl -n "${ns}" get deploy broken -o jsonpath='{.status.observedGeneration}')
  if [[ "${gen:-0}" -ge 2 ]]; then
    pass "broken observedGeneration=${gen} (>=2 means it was edited)"
  else
    warn "broken observedGeneration=${gen:-0}; edits not yet observed"
  fi
else
  fail "deployment/broken missing"
fi

# C2 — triage playbook.
if kubectl -n "${ns}" get configmap triage-playbook >/dev/null 2>&1; then
  size=$(kubectl -n "${ns}" get configmap triage-playbook -o jsonpath='{.data.playbook\.md}' | wc -c | tr -d ' ')
  if [[ "${size:-0}" -ge 100 ]]; then
    pass "triage-playbook has a non-trivial playbook.md (${size} bytes)"
  else
    fail "triage-playbook.playbook.md seems empty (${size:-0} bytes)"
  fi
else
  fail "configmap/triage-playbook missing"
fi

# C3 — metrics-server.
if kubectl get apiservices v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  avail=$(kubectl get apiservices v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
  if [[ "${avail}" == "True" ]]; then
    pass "metrics.k8s.io APIService is Available"
  else
    fail "metrics.k8s.io APIService is not Available (got: ${avail:-<none>})"
  fi
  if kubectl top pods -n "${ns}" >/dev/null 2>&1; then
    pass "kubectl top pods works in ${ns}"
  else
    warn "metrics installed but 'kubectl top pods' not returning data yet"
  fi
else
  fail "metrics-server APIService not registered"
fi

summary
