#!/usr/bin/env bash
# Capstone reference install.
#
#   ./install.sh           # helm install scribe ./charts/scribe -n lab-12
#   ./install.sh manifests # plain kubectl apply -f manifests/

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-helm}"

case "${mode}" in
  helm)
    helm upgrade --install scribe "${here}/charts/scribe" \
      --namespace lab-12 \
      --create-namespace \
      --wait --timeout=180s
    ;;
  manifests)
    # The flat manifests in manifests/ are a `helm template` snapshot for
    # the no-Helm path described in the README.
    kubectl apply -f "${here}/manifests/"
    ;;
  *)
    echo "usage: $0 [helm|manifests]" >&2; exit 2 ;;
esac

kubectl -n lab-12 get all,ing,netpol,hpa,secret,cm
