# Shared assertion helpers used by preflight and every lab's verify.sh.
#
# Source this file; do not execute it directly:
#
#   source "$(dirname "$0")/../../lib/verify.sh"
#
# The contract for lab verifiers:
#   - Every check prints a single line starting with PASS or FAIL.
#   - `summary` at the end of the script prints totals and exits non-zero
#     on any FAIL.
#   - Verifiers must be idempotent — running twice in a row must give the
#     same answer.

# Counters. Exported so sub-shells don't drop increments.
_K8S_LAB_PASS=${_K8S_LAB_PASS:-0}
_K8S_LAB_FAIL=${_K8S_LAB_FAIL:-0}

# ANSI colors, but only if stdout is a TTY.
if [[ -t 1 ]]; then
  _C_GREEN=$'\033[32m'
  _C_RED=$'\033[31m'
  _C_YELLOW=$'\033[33m'
  _C_BOLD=$'\033[1m'
  _C_RESET=$'\033[0m'
else
  _C_GREEN=""
  _C_RED=""
  _C_YELLOW=""
  _C_BOLD=""
  _C_RESET=""
fi

header() {
  printf '\n%s== %s ==%s\n' "${_C_BOLD}" "$*" "${_C_RESET}"
}

pass() {
  _K8S_LAB_PASS=$((_K8S_LAB_PASS + 1))
  printf 'PASS %s%s%s\n' "${_C_GREEN}" "$*" "${_C_RESET}"
}

fail() {
  _K8S_LAB_FAIL=$((_K8S_LAB_FAIL + 1))
  printf 'FAIL %s%s%s\n' "${_C_RED}" "$*" "${_C_RESET}"
}

warn() {
  printf 'WARN %s%s%s\n' "${_C_YELLOW}" "$*" "${_C_RESET}"
}

# Run a command and treat success/failure as a check.
# Usage: check "description" <command>
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass "${desc}"
  else
    fail "${desc}"
  fi
}

require_command() {
  local cmd="$1" reason="${2:-required}"
  if command -v "${cmd}" >/dev/null 2>&1; then
    pass "${cmd} is installed ($(command -v "${cmd}"))"
  else
    fail "${cmd} missing — ${reason}"
  fi
}

# Compare two dotted version strings. Returns 0 if $1 >= $2.
version_ge() {
  # Pad both sides to 3 components.
  local IFS=.
  read -ra a <<<"${1//[^0-9.]/}"
  read -ra b <<<"${2//[^0-9.]/}"
  while (( ${#a[@]} < 3 )); do a+=("0"); done
  while (( ${#b[@]} < 3 )); do b+=("0"); done
  for i in 0 1 2; do
    if (( 10#${a[i]:-0} > 10#${b[i]:-0} )); then return 0; fi
    if (( 10#${a[i]:-0} < 10#${b[i]:-0} )); then return 1; fi
  done
  return 0
}

min_version() {
  local name="$1" actual="$2" expected="$3"
  if version_ge "${actual}" "${expected}"; then
    pass "${name} ${actual} >= ${expected}"
  else
    fail "${name} ${actual} < ${expected}"
  fi
}

# kubectl helpers --------------------------------------------------------

kube() {
  kubectl "$@"
}

# Assert a resource exists in a namespace. Usage:
#   assert_resource pod my-pod default
assert_resource() {
  local kind="$1" name="$2" ns="${3:-default}"
  if kube -n "${ns}" get "${kind}" "${name}" >/dev/null 2>&1; then
    pass "${kind}/${name} exists in ${ns}"
  else
    fail "${kind}/${name} missing in ${ns}"
  fi
}

# Assert that every pod matching a label selector is Ready.
# Usage: assert_pods_ready "app=web" default 2
assert_pods_ready() {
  local selector="$1" ns="${2:-default}" expected="${3:-1}"
  local ready
  ready=$(kube -n "${ns}" get pods -l "${selector}" \
    -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
    2>/dev/null | grep -c '^True$' || true)
  if [[ "${ready}" -ge "${expected}" ]]; then
    pass "${ready}/${expected} pods Ready for selector '${selector}' in ${ns}"
  else
    fail "${ready}/${expected} pods Ready for selector '${selector}' in ${ns}"
  fi
}

# Assert a jsonpath extraction matches an expected value exactly.
# Usage: assert_jsonpath deployment web default '{.spec.replicas}' '3'
assert_jsonpath() {
  local kind="$1" name="$2" ns="$3" path="$4" expected="$5"
  local actual
  actual=$(kube -n "${ns}" get "${kind}" "${name}" -o jsonpath="${path}" 2>/dev/null || true)
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${kind}/${name} ${path} == ${expected}"
  else
    fail "${kind}/${name} ${path} == ${expected} (got: ${actual:-<empty>})"
  fi
}

# Wait for a condition on a resource (timeout seconds).
wait_for() {
  local kind="$1" name="$2" ns="$3" condition="$4" timeout="${5:-60s}"
  kube -n "${ns}" wait --for="${condition}" "${kind}/${name}" --timeout="${timeout}" >/dev/null 2>&1
}

# Run a one-shot curl from inside the cluster and echo its body.
cluster_curl() {
  local url="$1"
  kube run curl-$$-"${RANDOM}" --rm -i --restart=Never --image=curlimages/curl:8.7.1 -- \
    curl -sS --max-time 5 "${url}"
}

summary() {
  local total=$((_K8S_LAB_PASS + _K8S_LAB_FAIL))
  printf '\n%sSummary%s: %s%d passed%s, %s%d failed%s (of %d)\n' \
    "${_C_BOLD}" "${_C_RESET}" \
    "${_C_GREEN}" "${_K8S_LAB_PASS}" "${_C_RESET}" \
    "${_C_RED}" "${_K8S_LAB_FAIL}" "${_C_RESET}" \
    "${total}"
  if (( _K8S_LAB_FAIL > 0 )); then
    exit "${_K8S_LAB_FAIL}"
  fi
}
