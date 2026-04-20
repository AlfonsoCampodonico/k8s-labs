#!/usr/bin/env bash
# Lab 01 — pods. Checks the citizen pod has the right labels, probes, and
# containers, and that the failer pod is being restarted.

set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 01 — pods"

ns="lab-01"

# Namespace exists.
if kubectl get ns "${ns}" >/dev/null 2>&1; then
  pass "namespace ${ns} exists"
else
  fail "namespace ${ns} missing"
  summary
fi

# C1 — citizen pod with labels + annotation + probe + resources.
if kubectl -n "${ns}" get pod citizen >/dev/null 2>&1; then
  pass "pod citizen exists in ${ns}"

  for kv in app=citizen tier=frontend lab=01; do
    k="${kv%%=*}"; v="${kv##*=}"
    got=$(kubectl -n "${ns}" get pod citizen -o jsonpath="{.metadata.labels.${k}}")
    if [[ "${got}" == "${v}" ]]; then
      pass "citizen has label ${kv}"
    else
      fail "citizen label ${k}=${v} (got: ${got:-<none>})"
    fi
  done

  owner=$(kubectl -n "${ns}" get pod citizen -o jsonpath='{.metadata.annotations.owner}')
  if [[ -n "${owner}" ]]; then
    pass "citizen annotation owner=${owner}"
  else
    fail "citizen missing owner annotation"
  fi

  probe=$(kubectl -n "${ns}" get pod citizen -o jsonpath='{.spec.containers[?(@.name=="app")].readinessProbe.httpGet.path}')
  if [[ "${probe}" == "/readyz" ]]; then
    pass "citizen app readinessProbe is /readyz"
  else
    fail "citizen readinessProbe path (got: ${probe:-<none>})"
  fi

  cpu_req=$(kubectl -n "${ns}" get pod citizen -o jsonpath='{.spec.containers[?(@.name=="app")].resources.requests.cpu}')
  mem_req=$(kubectl -n "${ns}" get pod citizen -o jsonpath='{.spec.containers[?(@.name=="app")].resources.requests.memory}')
  if [[ -n "${cpu_req}" && -n "${mem_req}" ]]; then
    pass "citizen has CPU+memory requests (${cpu_req}, ${mem_req})"
  else
    fail "citizen missing resource requests"
  fi

  # C2 — init container named wait-dns.
  init=$(kubectl -n "${ns}" get pod citizen -o jsonpath='{.spec.initContainers[?(@.name=="wait-dns")].name}')
  if [[ "${init}" == "wait-dns" ]]; then
    pass "citizen has init container wait-dns"
  else
    fail "citizen missing init container wait-dns"
  fi

  # C3 — sidecar named logger.
  side=$(kubectl -n "${ns}" get pod citizen -o jsonpath='{.spec.containers[?(@.name=="logger")].name}')
  if [[ "${side}" == "logger" ]]; then
    pass "citizen has sidecar container logger"
  else
    fail "citizen missing sidecar container logger"
  fi

  assert_pods_ready "app=citizen" "${ns}" 1
else
  fail "pod citizen missing in ${ns}"
fi

# C4 — failer restarts on failure.
if kubectl -n "${ns}" get pod failer >/dev/null 2>&1; then
  pass "pod failer exists in ${ns}"
  policy=$(kubectl -n "${ns}" get pod failer -o jsonpath='{.spec.restartPolicy}')
  if [[ "${policy}" == "OnFailure" ]]; then
    pass "failer restartPolicy=OnFailure"
  else
    fail "failer restartPolicy=OnFailure (got: ${policy})"
  fi
  # Give the pod a couple of minutes of observed life to have at least 1 restart.
  restarts=$(kubectl -n "${ns}" get pod failer -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo 0)
  if [[ "${restarts:-0}" -ge 1 ]]; then
    pass "failer has restarted ${restarts} time(s)"
  else
    warn "failer has not restarted yet — wait ~10s and re-run"
  fi
else
  fail "pod failer missing in ${ns}"
fi

summary
