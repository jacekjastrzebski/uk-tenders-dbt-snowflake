# Architecture

How the tracker is built: a scheduled Python loader inside Snowflake stores Find a Tender notices unchanged, dbt turns them into a star schema 20 minutes later, and a Power BI report reads the marts. GitHub Actions tests every change and deploys what changed. The diagrams are in [`diagrams/`](diagrams/); to run your own copy, see [self-hosting.md](self-hosting.md).

**Start here (5 minutes):** [system context](diagrams/c4.md#system-context) → [containers](diagrams/c4.md#containers) → [notice to dashboard](diagrams/flows.md#notice-to-dashboard) → [layers and grain](diagrams/data.md#layers-and-grain).

## Diagrams

| | Diagram | Answers |
|---|---|---|
| **The system** | [System context](diagrams/c4.md#system-context) | Who uses it, and what it depends on |
| | [Containers](diagrams/c4.md#containers) | The moving parts and how data flows between them |
| | [Notice to dashboard](diagrams/flows.md#notice-to-dashboard) | The data's journey, lane by lane |
| | [Procurement in the model](diagrams/lifecycle.md#procurement-in-the-model) | Which notice fills which fact column |
| **The data** | [Layers and grain](diagrams/data.md#layers-and-grain) | What one row means at each layer |
| | [dbt lineage](diagrams/data.md#dbt-lineage) | Which model reads which |
| | [dbt project components](diagrams/c4.md#dbt-project-components) | What the dbt project holds besides models |
| | [Staging ERD](diagrams/staging-erd.md), [marts ERD](diagrams/marts-erd.md) | Keys and relationships, table by table |
| **Running it** | [Daily schedule](diagrams/flows.md#daily-schedule) | When each job runs |
| | [One ingest run](diagrams/flows.md#one-ingest-run) | What the loader does, call by call |
| | [dbt run and alerts](diagrams/flows.md#dbt-run-and-failure-alerts) | How dbt runs and how failures reach you |
| | [Scheduled tasks](diagrams/lifecycle.md#scheduled-tasks) | How tasks start, fail and stop |
| **Changing and securing it** | [Change to production](diagrams/flows.md#change-to-production) | How a code change reaches Snowflake |
| | [Roles and access](diagrams/security.md#roles-and-access) | Who can read or change what |
| | [Deployment](diagrams/c4.md#deployment) | What runs where |

## Main decisions

| Decision | Why | ADR |
|---|---|---|
| Run the loader inside Snowflake | No server of our own; schedule, logs and alerts in one place | [0001](adr/0001-run-ingestion-in-snowflake.md) |
| Run dbt on its own schedule, 20 minutes after each load | No orchestrator to run; loads take under a minute | [0009](adr/0009-run-dbt-on-a-schedule-in-snowflake.md) |
| One role per job; service users sign in with key pairs | Least privilege | [0004](adr/0004-least-privilege-roles-and-deploy-user.md) |
| Deploy on merge, only what changed, after CI | Every change tested; small deploys | [0005](adr/0005-deploy-only-changed-objects.md), [0019](adr/0019-deploy-after-ci-checks.md) |
| Star schema in `PROD_MARTS` for Power BI | Simple model, fast report, one read-only role | [0023](adr/0023-star-schema-for-power-bi.md), [0024](adr/0024-prod-schema-prefix.md) |

All decisions: [adr/](adr/README.md).

## Quality gates

| Gate | Where | Stops |
|---|---|---|
| pre-commit: private keys, YAML/TOML, mypy strict, pytest | Each commit, and CI | Broken Python, committed keys |
| CI must pass before deploy | `ci.yml` → `deploy.yml` | Untested code reaching Snowflake |
| Source freshness: warn 13 h, error 26 h | First step of `RUN_DBT` | Rebuilding marts on stale data |
| dbt tests: keys, relationships, singular tests | `dbt build` | Bad rows going unnoticed: a failing test fails the build |
| Failure alerts | 30 and 50 minutes past each run | Silent failures |

## Security and privacy

- Buyer contact details are personal data: they stay in `RAW`, staging strips them, and a dbt test enforces it ([ADR 0016](adr/0016-strip-contact-details-in-staging.md)).
- The deploy and Power BI users sign in with key pairs; the deploy key lives in a GitHub secret, and pre-commit blocks committed keys.
- The loader can reach one host only. Roles and grants: [security.md](diagrams/security.md).
- The data itself is public, under the Open Government Licence v3.0.

## Known gaps

Open items and their priority are in the [DataOps review](plans/dataops-review.md); the README lists what's done and what's next.
