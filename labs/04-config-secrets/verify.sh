#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 04 — config & secrets"

ns="lab-04"
assert_resource namespace "${ns}" ""

# C1 — podinfo deployment.
if kubectl -n "${ns}" get deploy podinfo >/dev/null 2>&1; then
  pass "deployment/podinfo exists"
  assert_jsonpath deployment podinfo "${ns}" '{.spec.replicas}' '2'
  assert_pods_ready "app=podinfo" "${ns}" 2
else
  fail "deployment/podinfo missing"
fi

# Secret mounted at /etc/podinfo/creds.
mount=$(kubectl -n "${ns}" get deploy podinfo \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/podinfo/creds")].name}' 2>/dev/null)
if [[ -n "${mount}" ]]; then
  pass "podinfo mounts a volume at /etc/podinfo/creds"
  # The backing volume must be a secret with name podinfo-creds.
  secret_name=$(kubectl -n "${ns}" get deploy podinfo \
    -o jsonpath="{.spec.template.spec.volumes[?(@.name==\"${mount}\")].secret.secretName}")
  if [[ "${secret_name}" == "podinfo-creds" ]]; then
    pass "secret podinfo-creds is mounted at /etc/podinfo/creds"
  else
    fail "volume at /etc/podinfo/creds is not secret podinfo-creds (got: ${secret_name:-<none>})"
  fi
else
  fail "podinfo does not mount anything at /etc/podinfo/creds"
fi

# Envs sourced from a ConfigMap.
cm_ref=$(kubectl -n "${ns}" get deploy podinfo \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].configMapRef.name}' 2>/dev/null)
if grep -Eqw 'podinfo-cfg|podinfo-cfg-v2' <<<"${cm_ref}"; then
  pass "podinfo consumes a ConfigMap via envFrom (${cm_ref})"
else
  fail "podinfo does not consume a ConfigMap via envFrom"
fi

# Both secrets + configmaps exist.
assert_resource configmap podinfo-cfg    "${ns}"
assert_resource configmap podinfo-cfg-v2 "${ns}"
assert_resource secret    podinfo-creds  "${ns}"

# C2 — podinfo-cfg-v2 must be immutable.
immutable=$(kubectl -n "${ns}" get configmap podinfo-cfg-v2 -o jsonpath='{.immutable}' 2>/dev/null)
if [[ "${immutable}" == "true" ]]; then
  pass "podinfo-cfg-v2 is immutable"
else
  fail "podinfo-cfg-v2 should be immutable (got: ${immutable:-false})"
fi

# C2 — running pods reference v2.
running_ref=$(kubectl -n "${ns}" get deploy podinfo \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].configMapRef.name}')
if grep -qw 'podinfo-cfg-v2' <<<"${running_ref}"; then
  pass "podinfo references podinfo-cfg-v2"
else
  fail "podinfo should reference podinfo-cfg-v2 (got: ${running_ref})"
fi

# C3 — broken-consumer is now Available.
if kubectl -n "${ns}" get deploy broken-consumer >/dev/null 2>&1; then
  avail=$(kubectl -n "${ns}" get deploy broken-consumer -o jsonpath='{.status.availableReplicas}')
  if [[ "${avail:-0}" -ge 1 ]]; then
    pass "broken-consumer has ${avail} available replica(s) — fix worked"
  else
    fail "broken-consumer has ${avail:-0} available replicas"
  fi
  # The fix should add a DB_URL key to broken-cfg.
  db=$(kubectl -n "${ns}" get configmap broken-cfg -o jsonpath='{.data.DB_URL}')
  if [[ -n "${db}" ]]; then
    pass "broken-cfg now has a DB_URL key"
  else
    fail "broken-cfg is missing DB_URL"
  fi
else
  warn "broken-consumer not deployed; skipping C3 checks"
fi

summary
