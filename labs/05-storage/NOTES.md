# Lab 05 — instructor notes

## Discussion prompts

- Why is RWX not offered by most cloud block storage? (Block devices
  are single-attach; RWX needs a filesystem-level service such as
  NFS/EFS/FSx.)
- Retain vs. Delete — which is safer by default, and when would you
  reverse the default? (Retain is safer for production data; Delete
  is convenient for ephemeral lab data. Switch defaults via a new
  StorageClass.)

## Mark scheme

9 checks; cap at 8 to keep the weight aligned with the syllabus.
