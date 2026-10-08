# 0028. Report navigation and market colours

Status: Accepted (2026-10-08)

## Context
The report has four question pages that people read in any order, and a public link (Publish to web) where viewers can't rely on Power BI's own page tabs. Its bar and line charts should show the digital and data market against the rest, and switch to one colour per market once a reader narrows the view.

## Decision
- **Home page and navigation.** A Home page explains the report and links to each page from a clickable tile. Every page has a "Navigate to" dropdown plus a Go button: Power BI can't change page when a slicer value is picked, so the button's destination is a measure (`Navigate To`) over a small DAX table (`Navigation`); the current page is filtered out of its own dropdown. No step numbers: the pages aren't a sequence.
- **Market colours.** Charts split their value by a legend table (`Colour Group`) through measures (`Awarded Value by Group`, `Median Days to Award by Group`): Digital and data (pink) against Other markets (navy) when nothing is picked; one colour per market once the Market, Sector or Buyer slicer is used. A legend filter keeps only groups with a value.
- **Detecting a slicer choice.** The measures test `ISFILTERED` on the slicer columns (`Sector[Market]`, `Sector[Sector]`, `Buyer[Buyer]`). Charts therefore group by hidden copies of the names (`Sector Name`, `Buyer Name`) and run their Top N on key columns, so neither their bars nor their Top N look like a slicer choice.
- **Helper tables** for slicers and legends (`Navigation`, `Closing Window`, `Colour Group`) are calculated in DAX and not linked to the model.

## Consequences
- Rejected: `COUNTROWS(ALLSELECTED(...))` (counts the chart's Top N as a selection), `CALCULATE(ISFILTERED(c), ALLSELECTED(c))` (always true) and Top N by `RANKX` inside the measures (correct but slow: every bar ranks all ~4,200 buyers).
- Ticking "Select all" in a slicer counts as a choice and shows per-market colours.
- With many markets picked, colours are hard to tell apart for colour-blind readers; the legend and tooltips name each market.
- `Days to Close` shows "Today / 1 day / n days" through a dynamic format string, which needs model compatibility level 1601.
