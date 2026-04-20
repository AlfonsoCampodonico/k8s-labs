#!/usr/bin/env bash
# Reference solution for lab 00.
# Try the challenges yourself before reading this.

set -euo pipefail

for ns in lab-00-alpha lab-00-beta; do
  kubectl get ns "${ns}" >/dev/null 2>&1 || kubectl create namespace "${ns}"
  kubectl label --overwrite namespace "${ns}" lab=bootstrap
  kubectl -n "${ns}" run sentinel --image=nginx:1.27-alpine \
    --restart=Never --labels=app=sentinel 2>/dev/null || true
  kubectl -n "${ns}" wait --for=condition=Ready pod/sentinel --timeout=60s
done

kubectl config set-context --current --namespace=lab-00-alpha
