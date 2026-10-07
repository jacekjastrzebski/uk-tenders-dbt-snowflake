# 0011. Overlap each load window by 15 minutes

Status: Accepted (2026-10-06, recorded 2026-10-07). Introduced with the first loader (`9f3cb90`); the reasons below were reconstructed afterwards, the value was not measured.

## Context
Each load fetches notices updated in a time window (`updatedFrom` / `updatedTo`). A window that starts exactly where the previous one ended risks missing notices at the edge:

- **Boundaries are not documented.** The API doesn't say whether `updatedFrom` and `updatedTo` are inclusive. A notice updated exactly at the boundary could fall between two windows.
- **Late visibility.** A notice's update time can be slightly earlier than the moment the API returns it (publishing or indexing lag), so a window that has just closed may still be missing it.
- **Duplicates are cheap; gaps are not.** dbt deduplicates on notice `id` (latest load wins), so loading a notice twice costs a few rows. A missed notice is silently lost.

## Decision
Start each window 15 minutes before the end of the last **successful** run (`OVERLAP` in `ingestion/load_find_a_tender.py`). A failed run doesn't move the window, so the next run re-fetches it.

15 minutes: long enough to cover boundary and lag effects of seconds to minutes, short compared with the 3-hour schedule.

## Consequences
- Some notices load twice: 27 of 178 rows in the first EDA (`docs/eda-findings.md`); `stg_find_a_tender__notices` removes them.
- Not verified: no measurement of how late notices actually become visible. If one is ever found missing, widen the overlap; the only cost is more duplicates.
- **Separate open risk: time zone.** The API's dates have no time zone and the docs don't say whether they mean UTC or UK local time; the loader sends UTC. If the API reads them as UK time, every window is shifted by one hour during BST. Consecutive windows still join up, so nothing is lost, but the newest hour arrives one run later. The 15-minute overlap does not cover this; check it by comparing a notice's `date` with the window that first loaded it.
