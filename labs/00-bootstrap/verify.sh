#!/usr/bin/env bash
# Lab 00 — bootstrap. Checks that the cluster is up, the expected
# namespaces exist, the sentinel pods are Ready, and the current
# kubeconfig default namespace is set.

set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 00 — bootstrap"

# 1. Cluster reachable.
check "kubectl can reach the API server" kubectl cluster-info

# 2. We're on the right context.
ctx=$(kubectl config current-context 2>/dev/null || true)
if [[ "${ctx}" == "kind-k8s-labs" ]]; then
  pass "current-context is kind-k8s-labs"
else
  fail "current-context is '${ctx:-unknown}', expected kind-k8s-labs"
fi

# 3. Three nodes are Ready (1 control-plane + 2 workers).
ready=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | tr ' ' '\n' | grep -c '^True$' || true)
if [[ "${ready}" -ge 3 ]]; then
  pass "${ready} nodes Ready (>= 3 expected)"
else
  fail "${ready} nodes Ready, expected >= 3"
fi

# C1 — namespaces with the lab=bootstrap label.
for ns in lab-00-alpha lab-00-beta; do
  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    label=$(kubectl get ns "${ns}" -o jsonpath='{.metadata.labels.lab}')
    if [[ "${label}" == "bootstrap" ]]; then
      pass "namespace ${ns} has label lab=bootstrap"
    else
      fail "namespace ${ns} label lab=bootstrap (got: ${label:-<none>})"
    fi
  else
    fail "namespace ${ns} does not exist"
  fi
done

# C2 — sentinel pod is Running + Ready in each namespace.
for ns in lab-00-alpha lab-00-beta; do
  assert_resource pod sentinel "${ns}"
  assert_pods_ready "run=sentinel,!purpose" "${ns}" 1 2>/dev/null || \
    assert_pods_ready "app=sentinel" "${ns}" 1 2>/dev/null || \
    # Fallback: check the pod named "sentinel" directly.
    if kubectl -n "${ns}" get pod sentinel >/dev/null 2>&1; then
      phase=$(kubectl -n "${ns}" get pod sentinel -o jsonpath='{.status.phase}')
      ready=$(kubectl -n "${ns}" get pod sentinel -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
      if [[ "${phase}" == "Running" && "${ready}" == "True" ]]; then
        pass "pod sentinel in ${ns} is Running+Ready"
      else
        fail "pod sentinel in ${ns} phase=${phase} ready=${ready}"
      fi
    fi
done

# C3 — default namespace in kubeconfig is lab-00-alpha.
default_ns=$(kubectl config view --minify -o jsonpath='{..namespace}')
if [[ "${default_ns}" == "lab-00-alpha" ]]; then
  pass "kubeconfig default namespace is lab-00-alpha"
else
  fail "kubeconfig default namespace is '${default_ns:-<none>}', expected lab-00-alpha"
fi

summary
