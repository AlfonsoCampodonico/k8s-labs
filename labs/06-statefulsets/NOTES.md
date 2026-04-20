# Lab 06 — instructor notes

## Discussion prompts

- Why does Kubernetes leave PVCs behind when a StatefulSet shrinks?
  (Safety. A scale-up must re-attach the same data.)
- What goes wrong if two StatefulSets share the same headless Service
  name? (DNS ambiguity. Kubernetes does not prevent this.)
- Why is StatefulSet not a complete database operator? (No backups,
  failover, leader election, schema migrations — those live in the
  application or an operator.)

## Mark scheme

10 checks, cap at 10.
