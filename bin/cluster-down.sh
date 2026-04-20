#!/usr/bin/env bash
# Delete the kind cluster.

set -euo pipefail

name="${1:-k8s-labs}"

if kind get clusters 2>/dev/null | grep -Fxq "${name}"; then
  kind delete cluster --name "${name}"
  echo "Deleted kind cluster '${name}'."
else
  echo "No kind cluster named '${name}' — nothing to do."
fi
