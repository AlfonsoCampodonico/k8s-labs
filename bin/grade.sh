#!/usr/bin/env bash
# Run every lab verifier and emit a Markdown report on stdout.
#
# Intended for instructor use — it assumes the current kubectl context is
# pointing at the student's cluster. It does not reset or mutate state.

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

{
  echo "# k8s-labs grading report"
  echo
  echo "- Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "- Context:   $(kubectl config current-context 2>/dev/null || echo 'unknown')"
  echo
  echo "| Lab | Score | Status |"
  echo "|-----|:-----:|--------|"
} >&1

total_pass=0
total_fail=0

for lab_dir in "${root}"/labs/*/; do
  lab_id="$(basename "${lab_dir}" | awk -F- '{print $1}')"
  verify="${lab_dir}verify.sh"
  if [[ ! -x "${verify}" ]] && [[ ! -f "${verify}" ]]; then
    echo "| ${lab_id}  | n/a   | NO-VERIFIER |"
    continue
  fi

  log=$(bash "${verify}" 2>&1 || true)
  pass=$(grep -c '^PASS ' <<<"${log}" || true)
  fail=$(grep -c '^FAIL ' <<<"${log}" || true)
  score="${pass}/$((pass + fail))"
  status="PASS"
  if (( fail > 0 )); then
    status="FAIL"
  fi
  total_pass=$(( total_pass + pass ))
  total_fail=$(( total_fail + fail ))

  echo "| ${lab_id}  | ${score} | ${status} |"
done

echo
echo "**Overall: ${total_pass} / $((total_pass + total_fail))**"

exit $(( total_fail > 0 ? 1 : 0 ))
