#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 09 — rbac & security"

ns="lab-09"
assert_resource namespace "${ns}" ""

# C1 — SA + Role + RoleBinding.
assert_resource serviceaccount reader "${ns}"
assert_resource role pod-reader "${ns}"
if kubectl -n "${ns}" get rolebinding -o jsonpath='{range .items[*]}{.subjects[*].name}{"\n"}{end}' | grep -q '^reader$'; then
  pass "a RoleBinding in ${ns} references ServiceAccount reader"
else
  fail "no RoleBinding in ${ns} references SA reader"
fi

# can-i check.
if kubectl auth can-i get pods -n "${ns}" --as="system:serviceaccount:${ns}:reader" 2>/dev/null | grep -qi '^yes$'; then
  pass "reader can get pods in ${ns}"
else
  fail "reader should be able to get pods in ${ns}"
fi
if kubectl auth can-i delete pods -n "${ns}" --as="system:serviceaccount:${ns}:reader" 2>/dev/null | grep -qi '^no$'; then
  pass "reader cannot delete pods (least-privilege)"
else
  fail "reader should not be able to delete pods"
fi

# C2 — deployments + network policies.
for d in frontend backend; do
  assert_resource deployment "${d}" "${ns}"
  assert_pods_ready "app=${d}" "${ns}" 1
done
assert_resource service backend "${ns}"
assert_resource networkpolicy default-deny-ingress "${ns}"
assert_resource networkpolicy allow-frontend-to-backend "${ns}"

# Allow policy structure.
np_sel=$(kubectl -n "${ns}" get networkpolicy allow-frontend-to-backend -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
if [[ "${np_sel}" == "backend" ]]; then
  pass "allow-frontend-to-backend selects app=backend"
else
  fail "allow-frontend-to-backend podSelector (got: ${np_sel:-<none>})"
fi

# C3 — PSA label.
psa=$(kubectl get ns "${ns}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || true)
case "${psa}" in
  baseline|restricted) pass "namespace ${ns} enforces PSA '${psa}'" ;;
  *)                   fail "namespace ${ns} should enforce PSA baseline or stricter (got: ${psa:-<none>})" ;;
esac

summary
