# dbt: setup and usage

dbt turns the raw API pages in `TENDER_DB.RAW` into clean tables. The project is in `dbt/`. You run it from your computer against the `dev` target; Snowflake runs it against `prod` after each load ([Runs in Snowflake](#runs-in-snowflake)).

## Layers

| Layer | Schema (prod / dev) | Materialised as | Contents |
|---|---|---|---|
| Sources | `RAW` | tables, loaded by the stored procedure | One row per API page |
| Staging | `PROD_STAGING` / `DEV_STAGING` | tables ([ADR 0015](adr/0015-staging-as-tables.md)) | One row per notice, party, award, award supplier, contract; deduplicated, typed, no personal data |
| Intermediate | `PROD_INTERMEDIATE` / `DEV_INTERMEDIATE` | views | Business rules shared by marts, e.g. `int_awards` (one row per award across notices); not for Power BI |
| Seeds | `PROD_STAGING` / `DEV_STAGING` | tables, from CSV in `dbt/seeds/` | Reference data: HMRC exchange rates (refresh monthly: `uv run ingestion/fetch_hmrc_exchange_rates.py`, then commit the CSV; the test `assert_fx_rates_recent` warns when it falls behind), CPV divisions |
| Marts | `PROD_MARTS` / `DEV_MARTS` | tables | Star schema for Power BI ([ADR 0023](adr/0023-star-schema-for-power-bi.md)), see [Marts](#marts) |

dbt runs as role `TENDER_TRANSFORM` (`snowflake/setup/03_transform_role.sql`): it can read `RAW` and create its own schemas, nothing else. The `dev` target writes to `DEV_*` schemas, so development never overwrites prod.

## Set up (once)

1. Run `snowflake/setup/03_transform_role.sql` and `04_reporting_role.sql` as ACCOUNTADMIN (replace the user name at the end of each with yours). Run 04 before the first `dbt build`: the marts grant `SELECT` to `TENDER_REPORTER`, and a build fails if that role doesn't exist.
2. Install dbt: `uv sync --group dbt`.
3. Create `~/.dbt/profiles.yml` (outside the repo). It reuses the key from the Snowflake CLI setup ([snowflake-cli.md](snowflake-cli.md)); use the full path, dbt does not expand `~`:

   ```yaml
   uk_tenders:
     target: dev
     outputs:
       dev:
         type: snowflake
         account: <orgname>-<accountname>
         user: <user>
         authenticator: snowflake_jwt
         private_key_path: /home/<you>/.snowflake/key.p8
         role: TENDER_TRANSFORM
         database: TENDER_DB
         warehouse: TENDER_WH
         schema: DEV
         threads: 4
   ```

4. Check the connection: `uv run dbt debug --project-dir dbt`.

## Commands

Run from the repo root:

```bash
uv run dbt build --project-dir dbt                       # build all models and run all tests
uv run dbt build --project-dir dbt --select stg_find_a_tender__notices+   # one model and everything downstream
uv run dbt source freshness --project-dir dbt            # is the raw data recent?
uv run dbt docs generate --project-dir dbt && uv run dbt docs serve --project-dir dbt   # browse models and lineage
```

## Runs in Snowflake

The project is deployed as a dbt project object and runs on a schedule inside Snowflake ([ADR 0009](adr/0009-run-dbt-on-a-schedule-in-snowflake.md)):

| When (UK time) | What | Where |
|---|---|---|
| :00 at 07, 10, 13, 16, 19 | Load from the API | task `RAW.INGEST_FIND_A_TENDER` |
| :20 | `dbt source freshness`, then `dbt build --target prod` → `PROD_STAGING`, `PROD_MARTS` | task `DBT.RUN_DBT`, warehouse `TENDER_WH` |
| :50 | Email if a dbt run failed since the last check | alert `DBT.RUN_DBT_FAILED` |
| :50 | Email if no load or no dbt run has succeeded for 4 hours, e.g. a task suspended itself ([ADR 0033](adr/0033-pipeline-safeguards.md)) | alert `DBT.PIPELINE_STALE` |

- **Deploy:** merging a change under `dbt/` deploys a new version of `TENDER_DB.DBT.UK_TENDERS` (`snow dbt deploy` in `deploy.yml`, after CI). The prod profile is `snowflake/dbt/profiles.yml`. dbt is pinned to 1.12.3 there, because the account default (1.9.4) can't compile the project; local dbt is held to 1.12 in `pyproject.toml` (`<1.13`) so the two stay in step; when upgrading, check `SELECT SYSTEM$SUPPORTED_DBT_VERSIONS();` and move both pins together.
- **Run by hand:** `EXECUTE DBT PROJECT TENDER_DB.DBT.UK_TENDERS ARGS = 'build --target prod';`, or `EXECUTE TASK TENDER_DB.DBT.RUN_DBT;` to run the task as scheduled.
- **Logs:** Snowsight → Monitoring → dbt projects shows each run with its output. Task runs are in `TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'RUN_DBT'))`.
- **One-off setup:** run `snowflake/dbt/00_dbt_setup.sql` as ACCOUNTADMIN before the first deploy.
- **Failures:** any failing dbt command (a freshness error, a model or a test) makes `EXECUTE DBT PROJECT` raise an error, so the task run fails and the alert emails. A freshness error stops the task before the build. Checked on 2026-10-08 with a missing macro, a division by zero and a failing test ([ADR 0033](adr/0033-pipeline-safeguards.md)).

## CI

Every pull request parses the project; pull requests that change `dbt/` also build every model and run every test into temporary `CI_PR_<number>_*` schemas, which are dropped afterwards ([ADR 0030](adr/0030-build-dbt-in-ci.md)). The build signs in as service user `TENDER_CI`, whose role can read `RAW` and create its own schemas but can't touch `PROD_*` (`snowflake/setup/06_ci_role.sql`, [ADR 0033](adr/0033-pipeline-safeguards.md)). The `dbt` job is a required check on `main`.

To try the same locally against throwaway schemas, with the same role (your user can use it through `SYSADMIN`):

```bash
export SNOWFLAKE_ACCOUNT=<orgname>-<accountname> SNOWFLAKE_USER=<user> SNOWFLAKE_PRIVATE_KEY_PATH=$HOME/.snowflake/key.p8 DBT_CI_SCHEMA=CI_TEST
# the role defaults to TENDER_CI; set SNOWFLAKE_ROLE to use another
uv run dbt build --project-dir dbt --profiles-dir .github/dbt
uv run dbt run-operation drop_ci_schemas --project-dir dbt --profiles-dir .github/dbt --args "{prefix: CI_TEST}"
```

## Conventions

- Model names: `stg_<source>__<entity>` (e.g. `stg_find_a_tender__awards`), plural entity.
- Every model has a key column tested `unique` and `not_null`; child rows use `<parent>/<child>` keys (e.g. `award_key = notice_id/award_id`).
- SQL style as in `CLAUDE.md`.
- Personal data (`parties[].contactPoint`) never leaves `RAW`; `dbt/tests/assert_no_contact_points.sql` enforces it.
- Staging timestamps are UTC (`TIMESTAMP_NTZ`), so date grouping doesn't depend on the session time zone.
- Organisation names that can't identify anyone (`[]`, `Test`, `N/A`, amounts) are replaced in staging with the same ID's usable name, else "Unnamed buyer/supplier (ID)" ([ADR 0025](adr/0025-replace-unusable-organisation-names.md)).
- A buyer ID published under 2–5 different names gets its most-used name ([ADR 0027](adr/0027-one-name-per-buyer-id.md)).
- Mart names: `fct_<entity>` for facts and `dim_<entity>` for dimensions, plural entity (e.g. `fct_award_suppliers`, `dim_dates`).
- Changing models, keys or relationships means updating the diagrams in [`docs/diagrams/`](diagrams/) (ERDs, `data.md`) in the same PR.

## Marts

Star schema for the Power BI report ([ADR 0023](adr/0023-star-schema-for-power-bi.md), [diagram](diagrams/marts-erd.md)). Built so far:

| Model | Grain | Used for |
|---|---|---|
| `dim_dates` | Day, 1990–2035 (vars in `dbt_project.yml`) | Date filters and trends; UK financial year |
| `dim_cpv_divisions` | CPV division (seed `cpv_divisions`), plus "Unknown sector" for notices without a CPV code | Sector and Market filters: 9 markets from the seed, e.g. Digital and data (48, 72) |
| `dim_buyers` | Buyer organisation, grouped by normalised name | Who's buying? |
| `dim_suppliers` | Supplier organisation, grouped by normalised name (lots removed); withheld flagged; plus "Unknown supplier" | Who's winning? |
| `dim_data_freshness` | One row: latest load time, UK | The report's "Data loaded" card |
| `fct_procurements` | Procurement Act tender (`ocid` with a UK4 notice) | What's open to bid? (closing_date from today, no award, not cancelled; `tender_value_gbp`, `is_framework`, `is_suitable_for_sme`, `tender_notice_url`, [ADR 0035](adr/0035-bidder-fields.md)) How long to award? (median `days_tender_to_award`) |
| `fct_award_suppliers` | Supplier on an award, deduplicated across notices ([ADR 0022](adr/0022-award-fact-rules.md)) | Who's buying? Who's winning? Sum `allocated_value_gbp` where `is_in_headline`; split by `competition` and `supplier_scale` ([ADR 0035](adr/0035-bidder-fields.md)) |

Access: Power BI reads the marts as role `TENDER_REPORTER` (`snowflake/setup/04_reporting_role.sql`), which can query `PROD_MARTS` and `DEV_MARTS` only. dbt grants `SELECT` on every mart table at each build (`+grants` in `dbt_project.yml`), so access survives rebuilds. Snowflake activates a user's other roles too (secondary roles), so for real least privilege Power BI should connect as its own user that has only `TENDER_REPORTER`; to test the role yourself, run `USE SECONDARY ROLES NONE` first.

Rules for fact date columns:

- Take the UK date, not the UTC one: `CONVERT_TIMEZONE('UTC', 'Europe/London', <timestamp>)::DATE`.
- Dates outside the calendar (e.g. the placeholder 2099-12-31) become NULL.
- Test each date column with `relationships` to `dim_dates.calendar_date`.
