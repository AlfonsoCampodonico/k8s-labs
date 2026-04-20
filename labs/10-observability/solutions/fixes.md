# Solutions — Lab 10

## C1 — the three fixes

```bash
# 1) Correct image
kubectl -n lab-10 set image deploy/broken app=ghcr.io/stefanprodan/podinfo:6.7.1

# 2) Add the missing ConfigMap key (adds a GREETING env that the template
#    references via envFrom — even though the manifest doesn't reference it
#    directly, missing keys are OK under envFrom. The real issue is that
#    students should still add it to demonstrate they noticed.)
kubectl -n lab-10 patch configmap app-cfg --type=merge -p '{"data":{"GREETING":"hello"}}'

# 3) Replace the immediate liveness probe with a sensible startup probe.
kubectl -n lab-10 patch deploy broken --type=json -p '[
  {"op":"remove","path":"/spec/template/spec/containers/0/livenessProbe"},
  {"op":"add","path":"/spec/template/spec/containers/0/startupProbe","value":{
    "httpGet":{"path":"/healthz","port":9898},
    "failureThreshold":30,"periodSeconds":2}}
]'
```

## C2 — triage playbook

See `triage-playbook.md` in this directory for a reference answer.

## C3 — metrics

```bash
kubectl apply -f ../../08-health-resources/manifests/metrics-server.yaml
```
