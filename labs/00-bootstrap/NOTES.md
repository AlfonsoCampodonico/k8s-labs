# Lab 00 — instructor notes

## Discussion prompts

- Why does the API server have a port 6443 TLS endpoint but etcd does
  not expose anything to the network? (Answer: etcd listens only on
  localhost on the control-plane node; only the API server talks to it,
  and that conversation uses mutual TLS with etcd-specific certs.)
- Which controller is responsible for the Node resource transitioning to
  `NotReady`? (Answer: the node lifecycle controller in
  `kube-controller-manager`, driven by kubelet heartbeats.)
- What happens if you delete the `default` service account from a
  namespace? (Answer: a controller re-creates it. This is a nice teaching
  moment about how controllers observe+reconcile.)

## Common student pitfalls

- They skip preflight and run into Docker not being started. Always
  begin lecture with a live `./bin/preflight.sh`.
- They create namespaces imperatively and forget the label. Emphasise
  that `kubectl label` is the easiest way to add it after the fact.
- They don't realise `--restart=Never` on `kubectl run` creates a raw
  Pod; without it they get a Deployment-ish thing (actually a Pod only
  on 1.18+, but it's still idiomatic to be explicit).

## Mark scheme

- 5 checks in `verify.sh`: preflight, context, nodes, two namespaces,
  two sentinels, kubeconfig default namespace — 1 mark each, 7 total.
  Verifier caps at 5 public marks; extras are carry-over bonus.
