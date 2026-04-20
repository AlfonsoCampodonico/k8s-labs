#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 12 — capstone (sanity check)"

ns="lab-12"
assert_resource namespace "${ns}" ""

# Workloads.
for d in frontend backend; do
  assert_resource deployment "${d}" "${ns}"
  assert_pods_ready "app=${d}" "${ns}" 1 2>/dev/null || \
    assert_pods_ready "app.kubernetes.io/name=${d}" "${ns}" 1 2>/dev/null || \
    fail "${d} has no Ready pods under either 'app=${d}' or 'app.kubernetes.io/name=${d}'"
done

if kubectl -n "${ns}" get statefulset postgres >/dev/null 2>&1; then
  pass "statefulset/postgres exists"
else
  fail "statefulset/postgres missing"
fi

# Services.
for s in frontend backend postgres; do
  assert_resource service "${s}" "${ns}"
done

# Ingress.
if kubectl -n "${ns}" get ingress -o jsonpath='{range .items[*]}{.spec.rules[0].host}{"\n"}{end}' 2>/dev/null | grep -q 'scribe.k8s-labs.test'; then
  pass "Ingress for scribe.k8s-labs.test exists"
else
  fail "No Ingress found for host scribe.k8s-labs.test"
fi

# Secret + ConfigMap.
assert_resource secret postgres-credentials "${ns}"

cm_count=$(kubectl -n "${ns}" get configmap -o name 2>/dev/null | grep -vc '^configmap/kube-root-ca.crt$' || true)
if [[ "${cm_count}" -ge 1 ]]; then
  pass "${cm_count} ConfigMap(s) present in ${ns}"
else
  fail "no ConfigMaps in ${ns}"
fi

# HPA.
if kubectl -n "${ns}" get hpa -o jsonpath='{.items[*].spec.scaleTargetRef.name}' 2>/dev/null | grep -qw backend; then
  pass "HorizontalPodAutoscaler targets backend"
else
  fail "no HPA targeting 'backend' found"
fi

# NetworkPolicies.
if kubectl -n "${ns}" get networkpolicy -o json | jq -e '[.items[] | select(.spec.podSelector == {})] | length >= 1' >/dev/null 2>&1; then
  pass "default-deny style NetworkPolicy present"
else
  fail "no default-deny NetworkPolicy (podSelector {}) in ${ns}"
fi

# PSA label.
psa=$(kubectl get ns "${ns}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || true)
case "${psa}" in
  baseline|restricted) pass "PSA enforce=${psa}" ;;
  *) fail "PSA enforce should be baseline or restricted (got: ${psa:-<none>})" ;;
esac

# Helm release (optional but encouraged).
if command -v helm >/dev/null 2>&1 && helm list -n "${ns}" -q 2>/dev/null | grep -qx scribe; then
  pass "helm release 'scribe' present"
else
  warn "helm release 'scribe' not found — Helm packaging is a grading criterion"
fi

summary
