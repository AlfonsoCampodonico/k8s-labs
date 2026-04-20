# Lab 04 — instructor notes

## Discussion prompts

- When would you use `projected` volumes instead of a plain ConfigMap
  / Secret volume? (Combining multiple sources into one directory,
  e.g. TLS cert + service-account token + ConfigMap.)
- If `base64` is not encryption, how do real deployments protect
  secrets? (Encryption at rest via KMS provider, or external stores
  like Vault / AWS Secrets Manager + CSI driver.)
- Why is immutable configuration not the default? (Backward
  compatibility, and plenty of workloads legitimately want to observe
  hot-reloads. But for production it is almost always what you want.)

## Mark scheme

12 checks, cap at 10.
