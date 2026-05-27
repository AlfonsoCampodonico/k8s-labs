#!/usr/bin/env bash
# Apply every lab's reference solution to the current cluster and run its
# verifier. This is the course author's smoke test — "do my reference
# solutions actually satisfy their own graders?" — not a student tool.
#
# Assumes the cluster is up. Does NOT reset state between labs: each lab
# owns its own `lab-NN` namespace, so accumulated state is harmless.
#
# Dispatch precedence inside each solutions/ directory:
#   1. install.sh   (e.g. lab 12 capstone — helm install)
#   2. solution.sh  (e.g. lab 00 bootstrap, lab 11 helm)
#   3. *.yaml / *.yml at the top level (labs 01–10)
#
# Exits non-zero if any lab's verifier reports a FAIL.

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# ANSI only if stdout is a TTY.
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; RED=$'\033[31m'
  YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; RED=""; YELLOW=""; RESET=""
fi

declare -a results=()
overall=0

apply_solution() {
  local dir="$1"
  if [[ -f "${dir}/install.sh" ]]; then
    bash "${dir}/install.sh"
  elif [[ -f "${dir}/solution.sh" ]]; then
    bash "${dir}/solution.sh"
  else
    # Apply every YAML at the top of solutions/. Skips non-YAML files
    # (e.g. lab 10's markdown notes) because `kubectl apply -f file.md`
    # would only happen if we listed it explicitly, and we don't.
    local applied=0
    shopt -s nullglob
    for f in "${dir}"/*.yaml "${dir}"/*.yml; do
      kubectl apply -f "${f}"
      applied=1
    done
    shopt -u nullglob
    if (( applied == 0 )); then
      return 2
    fi
  fi
}

for lab_dir in "${root}"/labs/*/; do
  lab="$(basename "${lab_dir}")"
  sol_dir="${lab_dir}solutions"
  verify="${lab_dir}verify.sh"

  printf '\n%s=== %s ===%s\n' "${BOLD}" "${lab}" "${RESET}"

  if [[ ! -d "${sol_dir}" ]]; then
    results+=("${YELLOW}SKIP${RESET}   ${lab}  (no solutions/ dir)")
    continue
  fi

  if apply_solution "${sol_dir}"; then
    # Wait for the lab's resources to converge before the verifier looks.
    # Match `lab-NN` and `lab-NN-*` namespaces (lab 00 uses two).
    lab_num="${lab%%-*}"
    nss="$(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
           | grep -E "^lab-${lab_num}(-|$)" || true)"
    for ns in ${nss}; do
      # Best-effort rollout wait for Deployments / StatefulSets / DaemonSets.
      while IFS= read -r r; do
        [[ -z "${r}" ]] && continue
        kubectl -n "${ns}" rollout status "${r}" --timeout=90s >/dev/null 2>&1 || true
      done < <(kubectl -n "${ns}" get deploy,sts,ds -o name 2>/dev/null)
      # Then give bare pods a chance to be Ready. `--all` includes pods that
      # are intentionally broken (lab 04 broken-consumer, lab 07 flaky jobs)
      # so this will time out for those labs — that's expected; the verifier
      # is the source of truth, not this wait.
      kubectl -n "${ns}" wait --for=condition=Ready pod --all --timeout=45s >/dev/null 2>&1 || true
      # Also wait for static-bound PVCs (e.g. lab 05 archive) that have
      # no pod consumer — the pod-Ready wait above misses those entirely.
      kubectl -n "${ns}" wait --for=jsonpath='{.status.phase}'=Bound pvc --all --timeout=30s >/dev/null 2>&1 || true
    done
  else
    rc=$?
    if (( rc == 2 )); then
      results+=("${YELLOW}SKIP${RESET}   ${lab}  (no appliable solution)")
      continue
    fi
    results+=("${RED}APPLY${RESET}  ${lab}  (install command exited ${rc})")
    overall=1
    continue
  fi

  if [[ ! -f "${verify}" ]]; then
    results+=("${YELLOW}SKIP${RESET}   ${lab}  (no verify.sh)")
    continue
  fi

  log="$(bash "${verify}" 2>&1)" || true
  pass="$(grep -c '^PASS ' <<<"${log}" || true)"
  fail="$(grep -c '^FAIL ' <<<"${log}" || true)"
  total=$(( pass + fail ))
  if (( fail == 0 && pass > 0 )); then
    results+=("${GREEN}PASS${RESET}   ${lab}  (${pass}/${total})")
  else
    results+=("${RED}FAIL${RESET}   ${lab}  (${pass}/${total})")
    overall=1
    grep -E '^FAIL ' <<<"${log}" || true
  fi
done

printf '\n%s=== Summary ===%s\n' "${BOLD}" "${RESET}"
for r in "${results[@]}"; do
  printf '  %s\n' "${r}"
done

exit "${overall}"
