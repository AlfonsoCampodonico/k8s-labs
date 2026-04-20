# Lab 07 — instructor notes

## Discussion prompts

- Why does `concurrencyPolicy: Allow` cause stampedes? (A slow job +
  a tight schedule compound.)
- Indexed Jobs replace the old "work queue" anti-pattern where each
  pod had to coordinate via Redis. Discuss when a queue is still right
  (dynamic workloads, backpressure).

## Mark scheme

10 checks, cap at 8.
