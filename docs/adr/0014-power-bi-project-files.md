# 0014. Power BI as a project (PBIP) in the repo

Status: Accepted (2026-10-07). Details: [powerbi.md](../powerbi.md).

## Context
A `.pbix` file is a binary: changes can't be reviewed in a PR, and two people editing it overwrite each other.

## Decision
Save the report as a Power BI Project (`powerbi/UkTenders.pbip`): the semantic model in TMDL, the report in PBIR (one JSON file per page and visual), the theme as JSON. Connection details are model parameters (schema `DEV_MARTS` or `MARTS`). Import mode.

## Consequences
- Every change is a readable diff; measures, relationships and visuals can be edited as code.
- Needs Power BI Desktop with the PBIP and PBIR features (current versions); the data cache and local settings are git-ignored, so the first open needs a refresh.
- Import mode: the report is as fresh as its last refresh, not as dbt's last run; schedule the refresh after dbt (:20) once published.
