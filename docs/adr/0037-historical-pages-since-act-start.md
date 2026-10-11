# 0037. Historical pages show everything since 24 February 2025

Status: Accepted (2026-10-11). Replaces the rolling 12 months in [0017](0017-backfill-from-procurement-act-start.md).

## Context
Home's tiles, Who's buying?, Who's winning? and How long to award? were filtered to the last 12 complete months, and each page had an "Awarded between" slider that could only narrow that window. Home said the data starts on 24 Feb 2025, but the sliders started at October 2025, so the report told two stories. A slider can't default to a moving window without saving fixed dates, and Desktop had saved them (2025-10-01 to 2026-10-01), which would have silently dropped every new month.

## Decision
- The historical pages show everything from 24 Feb 2025, when the Procurement Act 2023 came in, to the day of the latest refresh.
- The window is a hidden calculated column, `Date[In Report]` = `Date >= 24 Feb 2025 AND Date <= TODAY()`; each historical page filters `In Report = True`. It is recalculated at every refresh, so the report stores no dates.
- The "Awarded between" sliders keep no saved selection, start at 24 Feb 2025 and are synced across the three pages. The "Days waited" ranges (table `Wait Days`) take the same window.
- Headers keep fixed wording without a period; the slider and the footer show the dates.
- Footers and Home's "Time horizon" warn that the first months are thin (most awards then came from procurements begun under the old rules, which are left out) and that early waits look short.
- Buying and Winning date awards by the award decision (`Awards[Award Date]`); How long to award? and Home's median by the award notice (`Procurements[Award Published Date]`). Both use the same window.

## Consequences
- Totals grow over time: they mean "since 24 Feb 2025", not "per year". Labels say so.
- Readers can see the thin early months; the caveat explains them.
- No date to maintain and nothing that goes stale; a month change needs no report edit.
- The window's end is the last refresh, so a report that isn't refreshed shows older data; "Data as of" makes that visible.
