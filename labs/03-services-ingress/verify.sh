#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../lib/verify.sh"

header "Lab 03 — services & ingress"

ns="lab-03"
assert_resource namespace "${ns}" ""

# C1 — three services.
for svc in web web-stable web-canary; do
  assert_resource service "${svc}" "${ns}"
done

# ClusterIP with both tracks behind it.
cip=$(kubectl -n "${ns}" get svc web -o jsonpath='{.spec.clusterIP}')
if [[ -n "${cip}" && "${cip}" != "None" ]]; then
  pass "service/web has a ClusterIP (${cip})"
else
  fail "service/web should be ClusterIP (got: ${cip:-<none>})"
fi

# Headless services.
for svc in web-stable web-canary; do
  cip=$(kubectl -n "${ns}" get svc "${svc}" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
  if [[ "${cip}" == "None" ]]; then
    pass "service/${svc} is headless"
  else
    fail "service/${svc} should be headless (clusterIP: None), got '${cip}'"
  fi
done

# web service has >= 2 endpoints (stable + canary pods).
ep_count=$(kubectl -n "${ns}" get endpointslices -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' 2>/dev/null | grep -c . || true)
if [[ "${ep_count}" -ge 2 ]]; then
  pass "service/web has ${ep_count} endpoints (>=2 expected)"
else
  fail "service/web has ${ep_count} endpoints, expected >=2"
fi

# C2 — ingress.
if kubectl -n "${ns}" get ingress web-ingress >/dev/null 2>&1; then
  pass "ingress/web-ingress exists"
  class=$(kubectl -n "${ns}" get ingress web-ingress -o jsonpath='{.spec.ingressClassName}')
  if [[ "${class}" == "nginx" ]]; then
    pass "ingress uses class nginx"
  else
    fail "ingress class should be nginx (got: ${class:-<none>})"
  fi
  host=$(kubectl -n "${ns}" get ingress web-ingress -o jsonpath='{.spec.rules[0].host}')
  if [[ "${host}" == "web.k8s-labs.test" ]]; then
    pass "ingress host is web.k8s-labs.test"
  else
    fail "ingress host web.k8s-labs.test (got: ${host:-<none>})"
  fi
  # At least two paths — root and /canary.
  path_count=$(kubectl -n "${ns}" get ingress web-ingress -o jsonpath='{.spec.rules[0].http.paths[*].path}' | wc -w | tr -d ' ')
  if [[ "${path_count}" -ge 2 ]]; then
    pass "ingress has ${path_count} paths (>=2 expected)"
  else
    fail "ingress has ${path_count} paths, expected >=2"
  fi
else
  fail "ingress/web-ingress missing"
fi

# Live HTTP check — only if ingress-nginx is installed on control-plane.
if kubectl -n ingress-nginx get pods -l app.kubernetes.io/component=controller >/dev/null 2>&1; then
  code_root=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: web.k8s-labs.test' http://127.0.0.1:8080/ || echo "000")
  code_canary=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: web.k8s-labs.test' http://127.0.0.1:8080/canary || echo "000")
  if [[ "${code_root}" == "200" ]]; then
    pass "GET / returned 200"
  else
    fail "GET / returned ${code_root}"
  fi
  if [[ "${code_canary}" == "200" ]]; then
    pass "GET /canary returned 200"
  else
    fail "GET /canary returned ${code_canary}"
  fi
else
  warn "ingress-nginx not installed; skipping live HTTP checks"
fi

# C3 — broken-service was fixed (has endpoints) if it exists.
if kubectl -n "${ns}" get svc broken >/dev/null 2>&1; then
  bep=$(kubectl -n "${ns}" get endpointslices -l kubernetes.io/service-name=broken \
    -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' 2>/dev/null | grep -c . || true)
  if [[ "${bep}" -ge 1 ]]; then
    pass "service/broken has ${bep} endpoint(s) — selector was fixed"
  else
    fail "service/broken still has no endpoints"
  fi
fi

summary
