#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 06 — statefulsets"

ns="lab-06"
assert_resource namespace "${ns}" ""
assert_resource service web "${ns}"

# Headless service.
cip=$(kubectl -n "${ns}" get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
if [[ "${cip}" == "None" ]]; then
  pass "service/web is headless"
else
  fail "service/web should be headless (got clusterIP=${cip})"
fi

# StatefulSet.
if kubectl -n "${ns}" get statefulset web >/dev/null 2>&1; then
  pass "statefulset/web exists"
  assert_jsonpath statefulset web "${ns}" '{.spec.replicas}' '3'
  assert_jsonpath statefulset web "${ns}" '{.spec.serviceName}' 'web'
  vct=$(kubectl -n "${ns}" get statefulset web -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}')
  if [[ "${vct}" == "html" ]]; then
    pass "volumeClaimTemplate named html"
  else
    fail "volumeClaimTemplate should be html (got: ${vct:-<none>})"
  fi
  ready=$(kubectl -n "${ns}" get statefulset web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  if [[ "${ready:-0}" -eq 3 ]]; then
    pass "3/3 replicas Ready"
  else
    fail "web readyReplicas=${ready:-0}, expected 3"
  fi
else
  fail "statefulset/web missing"
fi

# Three PVCs, one per ordinal.
pvc_count=$(kubectl -n "${ns}" get pvc -l app=web -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "${pvc_count}" -ge 3 ]]; then
  pass "${pvc_count} PVCs exist for web (>=3 expected; scale-down preserves them)"
else
  fail "${pvc_count} PVCs for web, expected >=3"
fi

# Per-pod DNS + content via a short-lived curl pod.
if kubectl -n "${ns}" get pod web-0 >/dev/null 2>&1; then
  for i in 0 1 2; do
    body=$(kubectl -n "${ns}" run vcheck-${i}-$$ --rm -i --restart=Never --image=curlimages/curl:8.7.1 \
      --command -- sh -c "curl -sS --max-time 5 http://web-${i}.web.${ns}/ || true" 2>/dev/null)
    if grep -q "web-${i}" <<<"${body}"; then
      pass "web-${i} serves its own identity over DNS"
    else
      fail "web-${i} DNS/content: expected body containing 'web-${i}', got: ${body:-<empty>}"
    fi
  done
fi

summary
