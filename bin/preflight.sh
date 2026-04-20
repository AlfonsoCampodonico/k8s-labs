#!/usr/bin/env bash
# Verify the local toolchain meets the course's minimum requirements.
# Exits non-zero if anything is missing or out of date.

set -euo pipefail

# shellcheck source=../lib/verify.sh
source "$(dirname "$0")/../lib/verify.sh"

header "Preflight check"

require_command docker   "Docker (or podman alias) is required for kind nodes"
require_command kind     "kind creates the local Kubernetes cluster"
require_command kubectl  "kubectl talks to the cluster"
require_command helm     "helm is used in lab 11"
require_command jq       "jq is used by the automated graders"
require_command curl     "curl is used by several labs"
require_command bash     "bash 4+ is assumed by the graders"

min_version "kind"    "$(kind version | awk '{print $2}' | tr -d 'v')"    "0.22.0"
min_version "kubectl" "$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion' | tr -d 'v')" "1.29.0"
min_version "helm"    "$(helm version --template '{{.Version}}' | tr -d 'v')" "3.14.0"

# Docker daemon has to be running for kind to do anything.
if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not reachable. Start Docker Desktop / podman machine."
fi
pass "Docker daemon is reachable"

summary
