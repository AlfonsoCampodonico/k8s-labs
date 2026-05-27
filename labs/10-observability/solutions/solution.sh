#!/usr/bin/env bash
# Reference solution for lab 10.
#
# 1. Installs metrics-server with --kubelet-insecure-tls (kind nodes use
#    self-signed kubelet certs, so the default verification fails).
# 2. Applies solution.yaml (lab namespace + broken deployment + playbook).
#
# Idempotent: re-running upgrades / patches in place.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pin metrics-server to a known-good release.
METRICS_VERSION="v0.7.2"
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_VERSION}/components.yaml"

# Add --kubelet-insecure-tls only if it isn't already there. The patch is
# idempotent by content: applying the same JSON-patch op twice would add
# the arg twice, so check first.
if ! kubectl -n kube-system get deploy metrics-server \
     -o jsonpath='{.spec.template.spec.containers[0].args}' \
     | grep -q -- '--kubelet-insecure-tls'; then
  kubectl -n kube-system patch deployment metrics-server --type=json \
    -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi

kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

# The Deployment can be Ready before the aggregated APIService is
# Available — the kube-apiserver caches its discovery doc and needs a
# moment to mark v1beta1.metrics.k8s.io as healthy.
kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=120s

kubectl apply -f "${here}/solution.yaml"
kubectl -n lab-10 rollout status deploy/broken --timeout=60s || true
