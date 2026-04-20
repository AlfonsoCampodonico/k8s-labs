# Lab 03 — instructor notes

## Discussion prompts

- Why are `EndpointSlices` preferred over the old `Endpoints` object?
  (Scalability — Endpoints is a single object per Service; it gets huge
  for Services with thousands of pods.)
- Walk through the life of a packet: a pod hits a ClusterIP. (iptables
  in the PREROUTING chain DNATs to a pod IP chosen by probability;
  response goes back via conntrack.)
- Why does the NGINX Ingress controller need host networking / port
  80-443 exposed on a node? (Kind exposes those ports via extraPortMappings;
  on cloud you'd front it with a LoadBalancer.)

## Things that break

- Students install a different ingress class and wonder why their
  Ingress has no address. Make them `kubectl get ingressclasses` early.
- The rewrite annotation is NGINX-specific. Emphasise that ingress
  controllers are not interchangeable at the annotation level.

## Mark scheme

14 checks, cap at 10 (with two bonus marks for C4 MetalLB).
