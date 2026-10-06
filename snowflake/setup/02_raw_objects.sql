-- Raw landing tables for Find a Tender
USE ROLE SYSADMIN;

-- One row per API page, stored unchanged; dbt flattens the releases
CREATE TABLE IF NOT EXISTS TENDER_DB.RAW.FIND_A_TENDER_RELEASES (
  run_id       STRING,
  page_number  INTEGER,
  payload      VARIANT,
  loaded_at    TIMESTAMP_NTZ DEFAULT SYSDATE()  -- UTC
);

-- One row per loader run; the last successful window_to is the watermark
CREATE TABLE IF NOT EXISTS TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS (
  run_id         STRING,         -- run start time, e.g. 20261006T180000Z
  window_from    TIMESTAMP_NTZ,  -- UTC
  window_to      TIMESTAMP_NTZ,  -- UTC
  pages          INTEGER,
  releases       INTEGER,
  status         STRING,         -- success or failed
  error_message  STRING,
  finished_at    TIMESTAMP_NTZ DEFAULT SYSDATE()  -- UTC
);
