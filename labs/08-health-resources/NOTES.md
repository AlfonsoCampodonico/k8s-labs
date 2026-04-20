# Lab 08 — instructor notes

## Discussion prompts

- "Why does my HPA say `unknown`?" — metrics-server isn't healthy, or
  the pod has no CPU requests (utilization is relative to requests).
- Discuss why memory HPAs are often a bad idea: memory is sticky, so
  the controller oscillates.

## Mark scheme

11 checks, cap at 10.
