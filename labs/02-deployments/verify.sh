#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 02 — deployments"

ns="lab-02"
assert_resource namespace "${ns}" ""

# C1 — web deployment.
if kubectl -n "${ns}" get deploy web >/dev/null 2>&1; then
  pass "deployment/web exists"
  assert_jsonpath deployment web "${ns}" '{.spec.replicas}' '4'
  assert_jsonpath deployment web "${ns}" '{.spec.strategy.type}' 'RollingUpdate'
  assert_jsonpath deployment web "${ns}" '{.spec.strategy.rollingUpdate.maxSurge}' '1'
  assert_jsonpath deployment web "${ns}" '{.spec.strategy.rollingUpdate.maxUnavailable}' '0'
  assert_jsonpath deployment web "${ns}" '{.spec.revisionHistoryLimit}' '5'
  probe=$(kubectl -n "${ns}" get deploy web -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')
  if [[ "${probe}" == "/readyz" ]]; then
    pass "web readiness probe /readyz"
  else
    fail "web readiness probe /readyz (got: ${probe:-<none>})"
  fi
  assert_pods_ready "app=web,track=stable" "${ns}" 4
else
  fail "deployment/web missing"
fi

# C2 — rolled forward to 6.7.1 (or later).
img=$(kubectl -n "${ns}" get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
case "${img}" in
  ghcr.io/stefanprodan/podinfo:6.7.1|ghcr.io/stefanprodan/podinfo:6.7.2)
    pass "web image rolled forward (${img})" ;;
  *)
    fail "web image should be podinfo 6.7.1+ (got: ${img:-<none>})" ;;
esac

rs_count=$(kubectl -n "${ns}" get rs -l app=web -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "${rs_count}" -ge 2 ]]; then
  pass "web has ${rs_count} ReplicaSets on record (>=2 expected)"
else
  warn "web has only ${rs_count} ReplicaSet — rollout history is thin"
fi

# C3 — canary deployment.
if kubectl -n "${ns}" get deploy web-canary >/dev/null 2>&1; then
  pass "deployment/web-canary exists"
  assert_jsonpath deployment web-canary "${ns}" '{.spec.replicas}' '1'
  canary_img=$(kubectl -n "${ns}" get deploy web-canary -o jsonpath='{.spec.template.spec.containers[0].image}')
  if [[ "${canary_img}" == "ghcr.io/stefanprodan/podinfo:6.7.2" ]]; then
    pass "web-canary image is 6.7.2"
  else
    fail "web-canary image 6.7.2 (got: ${canary_img:-<none>})"
  fi
  track=$(kubectl -n "${ns}" get deploy web-canary -o jsonpath='{.spec.template.metadata.labels.track}')
  if [[ "${track}" == "canary" ]]; then
    pass "web-canary has track=canary label"
  else
    fail "web-canary track=canary (got: ${track:-<none>})"
  fi
  assert_pods_ready "app=web,track=canary" "${ns}" 1
else
  fail "deployment/web-canary missing"
fi

summary
