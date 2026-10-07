# Raw and staging on Apache Iceberg (future)

Status: idea, not scheduled. This project showcases Snowflake and dbt, so raw and staging stay in Snowflake-managed tables for now.

## Idea
Store raw and staging as **Apache Iceberg tables** on object storage (Azure Blob / ADLS, since the account runs on Azure) instead of Snowflake's internal storage.

## Why
- **Open format:** other engines (Spark, DuckDB, Databricks, Fabric) can read the same files without exporting from Snowflake.
- **No lock-in:** the data outlives a change of warehouse.
- **Storage cost** billed by the cloud provider; Snowflake only for compute.

## What would change
- An external volume pointing at the storage container, and Iceberg tables (`CREATE ICEBERG TABLE`) for `RAW` and `STAGING`, catalogued by Snowflake.
- The loader's inserts and dbt's table materialisation work the same; dbt models need `table_format='iceberg'` and the external volume in their config.
- Marts can stay Snowflake tables for Power BI speed.

## Check before doing it
- Iceberg support for `VARIANT` columns (the raw `payload` and `notice` JSON) and for streams/tasks used by ingestion.
- Cost of cloud storage and egress versus Snowflake storage at the expected data volume.
