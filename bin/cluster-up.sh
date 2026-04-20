#!/usr/bin/env bash
# Create (or re-use) the kind cluster used by the course.
#
# Usage: cluster-up.sh [cluster-name] [config-path]

set -euo pipefail

name="${1:-k8s-labs}"
config="${2:-clusters/kind-basic.yaml}"

if kind get clusters 2>/dev/null | grep -Fxq "${name}"; then
  echo "kind cluster '${name}' already exists — re-using it"
else
  echo "Creating kind cluster '${name}' from ${config}..."
  kind create cluster --name "${name}" --config "${config}" --wait 120s
fi

# Make sure kubectl is pointing at the cluster we just created.
kubectl config use-context "kind-${name}" >/dev/null
kubectl cluster-info --context "kind-${name}"

echo
echo "Nodes:"
kubectl get nodes -o wide

echo
echo "Ready. Verify with: kubectl get pods -A"
