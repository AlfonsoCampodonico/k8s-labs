# Kubernetes cheatsheet

A quick reference for the commands used throughout the course. This is not a
substitute for `kubectl --help`; think of it as the muscle-memory subset.

## Context & namespaces

```bash
kubectl config get-contexts
kubectl config use-context kind-k8s-labs
kubectl config set-context --current --namespace=lab-03

kubectl get namespaces
kubectl create namespace lab-03
```

## Inspecting resources

```bash
kubectl get pods                          # default namespace
kubectl get pods -A                       # all namespaces
kubectl get pods -o wide                  # include node & IP
kubectl get pod my-pod -o yaml            # full manifest
kubectl get pod my-pod -o jsonpath='{.status.phase}'

kubectl describe pod my-pod               # events + status
kubectl explain deployment.spec.strategy  # schema docs
```

## Creating & mutating

```bash
kubectl apply -f manifest.yaml            # declarative (preferred)
kubectl apply -k ./overlay                # kustomize
kubectl diff -f manifest.yaml             # dry-run diff
kubectl delete -f manifest.yaml

kubectl run tmp --image=nginx --rm -it -- bash
kubectl create deployment web --image=nginx --replicas=3
kubectl scale deployment web --replicas=5
kubectl rollout restart deployment/web
kubectl rollout status  deployment/web
kubectl rollout undo    deployment/web
```

## Debugging

```bash
kubectl logs pod/my-pod                   # all containers if only one
kubectl logs pod/my-pod -c sidecar        # specific container
kubectl logs -f deploy/web                # follow, pick one pod
kubectl logs --previous pod/my-pod        # last crashed container

kubectl exec -it pod/my-pod -- sh
kubectl port-forward svc/web 8080:80
kubectl debug pod/my-pod -it --image=busybox --target=app

kubectl get events --sort-by=.lastTimestamp
kubectl top pods
kubectl top nodes
```

## YAML authoring

```bash
# Dry-run an object as a starting template.
kubectl create deployment web --image=nginx --dry-run=client -o yaml

# Validate without applying.
kubectl apply -f manifest.yaml --dry-run=server

# Server-side apply (the modern default for automation).
kubectl apply -f manifest.yaml --server-side --field-manager=me
```

## JSONPath recipes

```bash
# List pod names with their node and phase.
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{.spec.nodeName}{"\t"}{.status.phase}{"\n"}{end}'

# Get the image of every container in every pod.
kubectl get pods -A -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}' | sort -u
```

## Kind-specific

```bash
kind get clusters
kind load docker-image my/app:dev --name k8s-labs     # push a local image
docker exec -it k8s-labs-control-plane bash          # shell into a node
```
