# Lab 09 — instructor notes

## Discussion prompts

- Why is `cluster-admin` rarely the right binding in production?
  (One compromised token, one compromised everything.)
- Why are NetworkPolicies ignored by pods no policy selects?
  (Additive model; see the spec.)
- What does PSA not protect against? (Misconfigured RBAC granting
  privileged policy; image vulnerabilities; runtime exploits.)

## Mark scheme

12 checks, cap at 10.
