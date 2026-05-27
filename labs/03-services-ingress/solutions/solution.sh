#!/usr/bin/env bash
# Reference solution for lab 03.
#
# 1. Installs ingress-nginx (kind provider variant) — the lab assumes it
#    is present so the curl checks at the end of verify.sh can hit the
#    control-plane's :8080 listener.
# 2. Applies web.yaml (Deployments, Services, Ingress).
#
# Idempotent: `kubectl apply` and `kubectl rollout status` both tolerate
# being re-run.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pin to a tagged release so the course is reproducible. The kind provider
# manifest sets nodeSelector ingress-ready=true (and hostPort 80/443) which
# matches the label we set on the control plane in clusters/kind-basic.yaml.
INGRESS_VERSION="controller-v1.11.2"
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_VERSION}/deploy/static/provider/kind/deploy.yaml"

# The kind manifest ships TWO jobs that provision the admission webhook's
# TLS cert and patch the ValidatingWebhookConfiguration with the right
# caBundle. Until both finish, the API server can't talk to the webhook
# and any `kubectl apply -f` containing an Ingress will be rejected with
# a TLS error. We must wait for both.
kubectl -n ingress-nginx wait --for=condition=Complete \
  job/ingress-nginx-admission-create \
  job/ingress-nginx-admission-patch \
  --timeout=120s

# Then wait for the controller pod (which serves the webhook) to be Ready.
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s
kubectl -n ingress-nginx wait --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller --timeout=60s

kubectl apply -f "${here}/web.yaml"
kubectl -n lab-03 rollout status deploy/web --timeout=120s
kubectl -n lab-03 rollout status deploy/web-canary --timeout=120s
