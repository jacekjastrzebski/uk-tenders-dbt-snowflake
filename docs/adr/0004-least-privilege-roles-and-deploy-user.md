# 0004. One role per job and a service user for deploys

Status: Accepted (2026-10-07)

## Context
Deploys first ran as the account owner's user, whose default role was ACCOUNTADMIN, so the key stored in GitHub could do anything in the account.

## Decision
- `TENDER_INGEST` owns and runs the loader (procedure, task, alert): insert into the raw tables, write to the code stage, create objects in `RAW`.
- `TENDER_TRANSFORM` runs dbt: read `RAW`, create and own its own schemas.
- Service user `TENDER_DEPLOY` (`TYPE = SERVICE`, key pair only) has `TENDER_INGEST` and is the only user GitHub Actions can log in as.
- Both roles are granted to SYSADMIN, so admins can manage everything.

## Consequences
- A leaked deploy key or a dbt bug can only affect its own objects.
- Account-level setup (`01_external_access.sql`, `03_transform_role.sql`, `04_reporting_role.sql`) stays manual and needs ACCOUNTADMIN.
- Leftover grants to SYSADMIN from earlier versions still need revoking (DataOps review, gap 3).
