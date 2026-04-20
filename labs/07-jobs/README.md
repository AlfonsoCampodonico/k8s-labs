# Lab 07 — Jobs & CronJobs

> **Est. time:** 3 hours.
> **Prereqs:** lab 01.

Not every workload is a long-running server. Batch processing, backups,
migrations, and scheduled reports need a workload controller whose
success condition is "runs to completion". That is a **Job**. A
**CronJob** is a scheduler that creates Jobs on a cron schedule.

## Learning outcomes

1. Run a single-completion Job and observe `completions` and `backoffLimit`.
2. Use `parallelism` and `completions` together for embarrassingly
   parallel workloads, and use `completionMode: Indexed` for
   work-queue-by-index patterns.
3. Configure a CronJob with `concurrencyPolicy` and
   `startingDeadlineSeconds`.
4. Debug a failing Job and understand the difference between a failed
   pod and a failed Job.

## Background

- `restartPolicy` for a Job must be `OnFailure` or `Never`; `Always`
  does not make sense for a batch workload.
- `backoffLimit` caps retries for a Job (default 6). After that the
  Job is marked `Failed`.
- `ttlSecondsAfterFinished` triggers automatic cleanup of completed
  Jobs' pods and the Job object itself. Without it, Jobs pile up.
- A CronJob's `concurrencyPolicy` can be `Allow`, `Forbid`, or
  `Replace`. `Forbid` is what you want for most nightly jobs.

## Guided walkthrough

### 1. A one-off Job

```bash
kubectl apply -f manifests/job-simple.yaml
kubectl get jobs
kubectl logs job/pi
```

### 2. A parallel Job

```bash
kubectl apply -f manifests/job-parallel.yaml
kubectl get pods -l job-name=mapreduce -w
```

### 3. An Indexed Job

```bash
kubectl apply -f manifests/job-indexed.yaml
kubectl get pods -l job-name=shards --sort-by=.metadata.name
kubectl logs pod/shards-0
kubectl logs pod/shards-3
```

### 4. A CronJob

```bash
kubectl apply -f manifests/cronjob.yaml
# Watch for a minute...
kubectl get cronjobs
kubectl get jobs
```

## Challenges

### C1. `report` Job

In `lab-07`, create a Job `report` that:

- image `busybox:1.36`
- runs `sh -c 'echo report-ok; sleep 2'`
- `completions=4`, `parallelism=2`
- `backoffLimit=0` (single attempt per pod)
- `ttlSecondsAfterFinished=300`

### C2. `nightly` CronJob

A CronJob `nightly` in `lab-07` that:

- schedules `*/2 * * * *` (every 2 minutes so the verifier can observe it)
- `concurrencyPolicy: Forbid`
- Job template runs `busybox:1.36` with `sh -c 'date; exit 0'`
- `successfulJobsHistoryLimit=1`, `failedJobsHistoryLimit=1`

### C3. A Job that retries and eventually gives up

A Job `flaky` in `lab-07` that always exits 1, with `backoffLimit=2`.
The verifier checks that `.status.failed >= 3` (initial + 2 retries)
and the Job's condition is `Failed`.

## Verification

```bash
make verify LAB=07
```

## Further reading

- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/).
- [CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/).
