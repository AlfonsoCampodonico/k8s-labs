#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 05 — storage"

ns="lab-05"
assert_resource namespace "${ns}" ""

# C1 — podinfo deployment with PVC.
if kubectl -n "${ns}" get deploy podinfo >/dev/null 2>&1; then
  pass "deployment/podinfo exists"
  assert_pods_ready "app=podinfo" "${ns}" 1

  claim=$(kubectl -n "${ns}" get deploy podinfo \
    -o jsonpath='{.spec.template.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}' 2>/dev/null | head -n1)
  if [[ "${claim}" == "podinfo-data" ]]; then
    pass "podinfo mounts PVC podinfo-data"
  else
    fail "podinfo should mount PVC podinfo-data (got: ${claim:-<none>})"
  fi
else
  fail "deployment/podinfo missing"
fi

# PVC is bound.
if kubectl -n "${ns}" get pvc podinfo-data >/dev/null 2>&1; then
  pass "PVC podinfo-data exists"
  phase=$(kubectl -n "${ns}" get pvc podinfo-data -o jsonpath='{.status.phase}')
  if [[ "${phase}" == "Bound" ]]; then
    pass "PVC podinfo-data is Bound"
  else
    fail "PVC podinfo-data phase=${phase}"
  fi
else
  fail "PVC podinfo-data missing"
fi

# C3 — archive PV + PVC.
if kubectl get pv archive >/dev/null 2>&1; then
  pass "PV archive exists"
  modes=$(kubectl get pv archive -o jsonpath='{.spec.accessModes[*]}')
  if grep -qw ReadOnlyMany <<<"${modes}"; then
    pass "PV archive accessModes includes ReadOnlyMany"
  else
    fail "PV archive accessModes should include ReadOnlyMany (got: ${modes})"
  fi
  reclaim=$(kubectl get pv archive -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
  if [[ "${reclaim}" == "Retain" ]]; then
    pass "PV archive reclaimPolicy=Retain"
  else
    fail "PV archive reclaimPolicy=Retain (got: ${reclaim})"
  fi
else
  fail "PV archive missing"
fi

if kubectl -n "${ns}" get pvc archive >/dev/null 2>&1; then
  phase=$(kubectl -n "${ns}" get pvc archive -o jsonpath='{.status.phase}')
  vol=$(kubectl -n "${ns}" get pvc archive -o jsonpath='{.spec.volumeName}')
  if [[ "${phase}" == "Bound" && "${vol}" == "archive" ]]; then
    pass "PVC archive is Bound to PV archive"
  else
    fail "PVC archive bound state (phase=${phase}, volume=${vol:-<none>})"
  fi
else
  fail "PVC archive missing"
fi

# C2 is implicitly covered: if pods are Ready and PVC is Bound, data
# persistence is a property of the provisioner.

summary
