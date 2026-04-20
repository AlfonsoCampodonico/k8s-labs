#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 07 — jobs & cronjobs"

ns="lab-07"
assert_resource namespace "${ns}" ""

# C1 — report Job.
if kubectl -n "${ns}" get job report >/dev/null 2>&1; then
  pass "job/report exists"
  assert_jsonpath job report "${ns}" '{.spec.completions}' '4'
  assert_jsonpath job report "${ns}" '{.spec.parallelism}' '2'
  assert_jsonpath job report "${ns}" '{.spec.backoffLimit}' '0'
  ttl=$(kubectl -n "${ns}" get job report -o jsonpath='{.spec.ttlSecondsAfterFinished}')
  if [[ -n "${ttl}" && "${ttl}" -ge 1 ]]; then
    pass "report ttlSecondsAfterFinished=${ttl}"
  else
    fail "report ttlSecondsAfterFinished unset"
  fi
  succ=$(kubectl -n "${ns}" get job report -o jsonpath='{.status.succeeded}' 2>/dev/null || echo 0)
  if [[ "${succ:-0}" -ge 4 ]]; then
    pass "report succeeded ${succ}/4"
  else
    warn "report succeeded=${succ:-0}; give it another minute"
  fi
else
  fail "job/report missing"
fi

# C2 — nightly CronJob.
if kubectl -n "${ns}" get cronjob nightly >/dev/null 2>&1; then
  pass "cronjob/nightly exists"
  assert_jsonpath cronjob nightly "${ns}" '{.spec.concurrencyPolicy}' 'Forbid'
  schedule=$(kubectl -n "${ns}" get cronjob nightly -o jsonpath='{.spec.schedule}')
  case "${schedule}" in
    *"*/2"*|*"*/1"*) pass "nightly schedule is '${schedule}'" ;;
    *)               fail "nightly schedule should fire frequently (got: ${schedule})" ;;
  esac
  assert_jsonpath cronjob nightly "${ns}" '{.spec.successfulJobsHistoryLimit}' '1'
else
  fail "cronjob/nightly missing"
fi

# C3 — flaky Job that eventually fails.
if kubectl -n "${ns}" get job flaky >/dev/null 2>&1; then
  failed=$(kubectl -n "${ns}" get job flaky -o jsonpath='{.status.failed}' 2>/dev/null || echo 0)
  cond=$(kubectl -n "${ns}" get job flaky -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)
  if [[ "${failed:-0}" -ge 3 ]]; then
    pass "flaky recorded ${failed} failed attempts"
  else
    warn "flaky has ${failed:-0} failed attempts; give it another minute"
  fi
  if [[ "${cond}" == "True" ]]; then
    pass "flaky is condition=Failed"
  else
    warn "flaky condition=Failed not True yet (got: ${cond:-<none>})"
  fi
else
  fail "job/flaky missing"
fi

summary
