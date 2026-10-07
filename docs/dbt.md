# dbt: setup and usage

dbt turns the raw API pages in `TENDER_DB.RAW` into clean tables. The project is in `dbt/`; for now it runs from your computer (scheduling it inside Snowflake comes later).

## Layers

| Layer | Schema (prod / dev) | Materialised as | Contents |
|---|---|---|---|
| Sources | `RAW` | tables, loaded by the stored procedure | One row per API page |
| Staging | `STAGING` / `DEV_STAGING` | views | One row per notice, party, award, award supplier, contract; deduplicated, typed, no personal data |
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

## Conventions

- Model names: `stg_<source>__<entity>` (e.g. `stg_find_a_tender__awards`), plural entity.
- Every model has a key column tested `unique` and `not_null`; child rows use `<parent>/<child>` keys (e.g. `award_key = notice_id/award_id`).
- SQL style as in `CLAUDE.md`.
- Personal data (`parties[].contactPoint`) never leaves `RAW`.
