#!/usr/bin/env bash
# Reference solution for lab 11.
#
# C1: install Bitnami NGINX as release `demo`.
# C2: install the local podinfo chart as release `myapp`.
#
# Idempotent: re-running upgrades the releases in place.

set -euo pipefail

ns=lab-11
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl get ns "${ns}" >/dev/null 2>&1 || kubectl create namespace "${ns}"

helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo update >/dev/null

# C1 — public chart.
helm upgrade --install demo bitnami/nginx \
  --namespace "${ns}" \
  --set service.type=ClusterIP \
  --set replicaCount=2 \
  --wait --timeout=180s

# C2 — local chart.
helm upgrade --install myapp "${here}/podinfo" \
  --namespace "${ns}" \
  --set replicaCount=2 \
  --set image.tag=6.7.1 \
  --set ingress.enabled=false \
  --wait --timeout=120s

helm list -n "${ns}"
