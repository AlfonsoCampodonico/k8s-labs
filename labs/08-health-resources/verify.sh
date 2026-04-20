#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 08 — health & resources"

ns="lab-08"
assert_resource namespace "${ns}" ""

# C1 — api deployment and its probes.
if kubectl -n "${ns}" get deploy api >/dev/null 2>&1; then
  pass "deployment/api exists"
  for probe in startupProbe readinessProbe livenessProbe; do
    path=$(kubectl -n "${ns}" get deploy api -o jsonpath="{.spec.template.spec.containers[0].${probe}.httpGet.path}" 2>/dev/null || true)
    if [[ -n "${path}" ]]; then
      pass "api has ${probe} configured (${path})"
    else
      fail "api missing ${probe}"
    fi
  done

  cpu_req=$(kubectl -n "${ns}" get deploy api -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
  mem_lim=$(kubectl -n "${ns}" get deploy api -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
  if [[ -n "${cpu_req}" && -n "${mem_lim}" ]]; then
    pass "api has CPU requests (${cpu_req}) and memory limits (${mem_lim})"
  else
    fail "api missing CPU requests or memory limits"
  fi
else
  fail "deployment/api missing"
fi

# C2 — QoS classes.
for want in BestEffort Burstable Guaranteed; do
  name="$(echo ${want} | tr '[:upper:]' '[:lower:]')"
  if kubectl -n "${ns}" get pod "${name}" >/dev/null 2>&1; then
    qos=$(kubectl -n "${ns}" get pod "${name}" -o jsonpath='{.status.qosClass}')
    if [[ "${qos}" == "${want}" ]]; then
      pass "pod/${name} qosClass=${want}"
    else
      fail "pod/${name} qosClass expected ${want}, got ${qos:-<none>}"
    fi
  else
    fail "pod/${name} missing"
  fi
done

# C3 — HPA.
if kubectl -n "${ns}" get hpa api >/dev/null 2>&1; then
  pass "hpa/api exists"
  assert_jsonpath hpa api "${ns}" '{.spec.minReplicas}' '2'
  assert_jsonpath hpa api "${ns}" '{.spec.maxReplicas}' '6'
  target=$(kubectl -n "${ns}" get hpa api -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}')
  if [[ "${target}" == "50" ]]; then
    pass "hpa targets 50% average CPU utilisation"
  else
    fail "hpa target averageUtilization=50 (got: ${target:-<none>})"
  fi
else
  fail "hpa/api missing"
fi

summary
