# 0019. Deploy only after the CI checks pass

Status: Accepted (2026-10-07). Changes the trigger in [ADR 0005](0005-deploy-only-changed-objects.md); what gets deployed is unchanged.

## Context
CI (`ci.yml`) and Deploy (`deploy.yml`) both started on every push to `main` and ran side by side, so a deploy did not wait for the checks. Branch protection already requires the `checks` job to pass on the PR, with the branch up to date, but admins can bypass it.

## Decision
- `ci.yml` calls `deploy.yml` as a reusable workflow, in a `deploy` job with `needs: checks`, on pushes to `main` only.
- `deploy.yml` no longer triggers on push; it keeps its manual run (`workflow_dispatch`).
- Deploy still runs each step only for files changed in the push. CI now calls it on every push, so the Snowflake connection is only written when something is to be deployed.

## Consequences
- A push that fails the checks never reaches Snowflake, even if branch protection was bypassed.
- Deploy starts about 30 seconds later, after the checks.
- In the Actions tab, Deploy appears as a job inside the CI run, not as its own workflow run.
