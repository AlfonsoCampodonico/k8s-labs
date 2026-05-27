#!/usr/bin/env bash
# Create (or re-use) the kind cluster used by the course.
#
# Usage: cluster-up.sh [cluster-name] [config-path]

set -euo pipefail

name="${1:-k8s-labs}"
config="${2:-clusters/kind-basic.yaml}"

create_cluster() {
  echo "Creating kind cluster '${name}' from ${config}..."
  kind create cluster --name "${name}" --config "${config}" --wait 120s
}

if kind get clusters 2>/dev/null | grep -Fxq "${name}"; then
  echo "kind cluster '${name}' already exists — re-using it"
  # Re-export kubeconfig in case the context was removed while the cluster
  # kept running (e.g. kubeconfig edited manually). `kind create` does this
  # automatically; the re-use path must do it explicitly.
  kind export kubeconfig --name "${name}" >/dev/null

  # Probe the API server. After a Docker Desktop / host restart the cluster
  # may exist but be wedged (kubelet crashloop, stale etcd, corrupt config).
  # Auto-recreate rather than confronting the student with cryptic memcache
  # errors on their first `make cluster`.
  if ! kubectl cluster-info --context "kind-${name}" --request-timeout=5s >/dev/null 2>&1; then
    echo "Cluster '${name}' is unhealthy (API unreachable); recreating from scratch..."
    kind delete cluster --name "${name}"
    create_cluster
  fi
else
  create_cluster
fi

# Make sure kubectl is pointing at the cluster we just created.
kubectl config use-context "kind-${name}" >/dev/null
kubectl cluster-info --context "kind-${name}"

# Apply role labels that kubelet refuses to self-apply (NodeRestriction
# blocks nodes from labeling themselves under kubernetes.io/).
kubectl label node "${name}-control-plane" \
  node-role.kubernetes.io/edge=true --overwrite >/dev/null

echo
echo "Nodes:"
kubectl get nodes -o wide

echo
echo "Ready. Verify with: kubectl get pods -A"
