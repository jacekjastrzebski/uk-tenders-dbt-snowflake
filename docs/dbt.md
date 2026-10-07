# dbt: setup and usage

dbt turns the raw API pages in `TENDER_DB.RAW` into clean tables. The project is in `dbt/`. You run it from your computer against the `dev` target; Snowflake runs it against `prod` after each load ([Runs in Snowflake](#runs-in-snowflake)).

## Layers

| Layer | Schema (prod / dev) | Materialised as | Contents |
|---|---|---|---|
| Sources | `RAW` | tables, loaded by the stored procedure | One row per API page |
| Staging | `STAGING` / `DEV_STAGING` | tables ([ADR 0015](adr/0015-staging-as-tables.md)) | One row per notice, party, award, award supplier, contract; deduplicated, typed, no personal data |
| Marts | `MARTS` / `DEV_MARTS` | to decide | Dashboard tables (next step) |

dbt runs as role `TENDER_TRANSFORM` (`snowflake/setup/03_transform_role.sql`): it can read `RAW` and create its own schemas, nothing else. The `dev` target writes to `DEV_*` schemas, so development never overwrites prod.

## Set up (once)

1. Run `snowflake/setup/03_transform_role.sql` as ACCOUNTADMIN (replace the user name at the end with yours).
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
| :20 | `dbt source freshness`, then `dbt build --target prod` → `STAGING`, `MARTS` | task `DBT.RUN_DBT`, warehouse `TENDER_WH` |
| :50 | Email if the dbt run failed | alert `DBT.RUN_DBT_FAILED` |

- **Deploy:** merging a change under `dbt/` deploys a new version of `TENDER_DB.DBT.UK_TENDERS` (`snow dbt deploy` in `deploy.yml`, after CI). The prod profile is `snowflake/dbt/profiles.yml`.
- **Run by hand:** `EXECUTE DBT PROJECT TENDER_DB.DBT.UK_TENDERS ARGS = 'build --target prod';`, or `EXECUTE TASK TENDER_DB.DBT.RUN_DBT;` to run the task as scheduled.
- **Logs:** Snowsight → Monitoring → dbt projects shows each run with its output. Task runs are in `TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'RUN_DBT'))`.
- **One-off setup:** run `snowflake/dbt/00_dbt_setup.sql` as ACCOUNTADMIN before the first deploy.
- **To check once after the first deploy:** that a failing dbt command fails the task, e.g. `EXECUTE DBT PROJECT TENDER_DB.DBT.UK_TENDERS ARGS = 'run-operation does_not_exist';` should raise an error. If it only returns a row with `success = FALSE`, the task body must check that flag and raise.

## Conventions

- Model names: `stg_<source>__<entity>` (e.g. `stg_find_a_tender__awards`), plural entity.
- Every model has a key column tested `unique` and `not_null`; child rows use `<parent>/<child>` keys (e.g. `award_key = notice_id/award_id`).
- SQL style as in `CLAUDE.md`.
- Personal data (`parties[].contactPoint`) never leaves `RAW`; `dbt/tests/assert_no_contact_points.sql` enforces it.
- Staging timestamps are UTC (`TIMESTAMP_NTZ`), so date grouping doesn't depend on the session time zone.
- Changing models, keys or relationships means updating [`docs/diagrams/staging-erd.md`](diagrams/staging-erd.md) in the same PR.
