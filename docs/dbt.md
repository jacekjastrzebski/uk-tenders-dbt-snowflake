# dbt: setup and usage

dbt turns the raw API pages in `TENDER_DB.RAW` into clean tables. The project is in `dbt/`; for now it runs from your computer (scheduling it inside Snowflake comes later).

## Layers

| Layer | Schema (prod / dev) | Materialised as | Contents |
|---|---|---|---|
| Sources | `RAW` | tables, loaded by the stored procedure | One row per API page |
| Staging | `STAGING` / `DEV_STAGING` | tables ([ADR 0015](adr/0015-staging-as-tables.md)) | One row per notice, party, award, award supplier, contract; deduplicated, typed, no personal data |
| Intermediate | `INTERMEDIATE` / `DEV_INTERMEDIATE` | views | Business rules shared by marts, e.g. `int_awards` (one row per award across notices); not for Power BI |
| Seeds | `STAGING` / `DEV_STAGING` | tables, from CSV in `dbt/seeds/` | Reference data: HMRC exchange rates, CPV divisions |
| Marts | `MARTS` / `DEV_MARTS` | tables | Star schema for Power BI ([ADR 0019](adr/0019-star-schema-for-power-bi.md)), see [Marts](#marts) |

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

## Conventions

- Model names: `stg_<source>__<entity>` (e.g. `stg_find_a_tender__awards`), plural entity.
- Every model has a key column tested `unique` and `not_null`; child rows use `<parent>/<child>` keys (e.g. `award_key = notice_id/award_id`).
- SQL style as in `CLAUDE.md`.
- Personal data (`parties[].contactPoint`) never leaves `RAW`; `dbt/tests/assert_no_contact_points.sql` enforces it.
- Staging timestamps are UTC (`TIMESTAMP_NTZ`), so date grouping doesn't depend on the session time zone.
- Mart names: `fct_<entity>` for facts and `dim_<entity>` for dimensions, plural entity (e.g. `fct_award_suppliers`, `dim_dates`).
- Changing models, keys or relationships means updating the diagrams in [`docs/diagrams/`](diagrams/) in the same PR.

## Marts

Star schema for the Power BI report ([ADR 0019](adr/0019-star-schema-for-power-bi.md), [diagram](diagrams/marts-erd.md)). Built so far:

| Model | Grain | Used for |
|---|---|---|
| `dim_dates` | Day, 1990–2035 (vars in `dbt_project.yml`) | Date filters and trends; UK financial year |
| `dim_cpv_divisions` | CPV division (seed `cpv_divisions`) | Sector filters; the digital and data market (48, 72) |
| `dim_buyers` | Buyer organisation, grouped by normalised name | Who's buying? |
| `dim_suppliers` | Supplier organisation, grouped by normalised name (lots removed); withheld flagged; plus "Unknown supplier" | Who's winning? |
| `fct_procurements` | Procurement Act tender (`ocid` with a UK4 notice) | What's open to bid? (closing_date from today, no award, not cancelled) How long to award? (median `days_tender_to_award`) |
| `fct_award_suppliers` | Supplier on an award, deduplicated across notices ([ADR 0022](adr/0022-award-fact-rules.md)) | Who's buying? Who's winning? Sum `allocated_value_gbp` where `is_in_headline` |

Access: Power BI reads the marts as role `TENDER_REPORTER` (`snowflake/setup/04_reporting_role.sql`), which can query `MARTS` and `DEV_MARTS` only. dbt grants `SELECT` on every mart table at each build (`+grants` in `dbt_project.yml`), so access survives rebuilds. Snowflake activates a user's other roles too (secondary roles), so for real least privilege Power BI should connect as its own user that has only `TENDER_REPORTER`; to test the role yourself, run `USE SECONDARY ROLES NONE` first.

Rules for fact date columns:

- Take the UK date, not the UTC one: `CONVERT_TIMEZONE('UTC', 'Europe/London', <timestamp>)::DATE`.
- Dates outside the calendar (e.g. the placeholder 2099-12-31) become NULL.
- Test each date column with `relationships` to `dim_dates.calendar_date`.
