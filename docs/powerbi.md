# Power BI report

The report reads the dbt marts ([dbt.md](dbt.md#marts)) and is stored as a Power BI Project, so the model and every visual are text files reviewed like code ([ADR 0014](adr/0014-power-bi-project-files.md)).

## Layout

| Path | Contents |
|---|---|
| `powerbi/UkTenders.pbip` | Open this in Power BI Desktop |
| `powerbi/UkTenders.SemanticModel/definition/` | Model in TMDL: `expressions.tmdl` (connection parameters), `tables/*.tmdl` (columns, measures), `relationships.tmdl` |
| `powerbi/UkTenders.Report/definition/` | Report in PBIR: `pages/<page>/page.json`, `pages/<page>/visuals/<visual>/visual.json` |
| `powerbi/UkTenders.Report/StaticResources/RegisteredResources/HippoDigital.json` | Theme: colours, fonts, visual defaults |

Not committed (`.gitignore`): `.pbi/cache.abf` (the imported data) and `.pbi/localSettings.json`.

## Pages

| Page | Question | Visuals |
|---|---|---|
| Open tenders and buyers | What is open, who is buying? | Open tenders, closing in 7 days, notices, awarded value; open tenders closing soonest; top buyers |
| Suppliers | Who is winning? | Awarded value, awards, suppliers, average award; top suppliers; value by sector; league table with market share |
| Pipeline and timings | How long does it take? | Procurements, median days tender → award and award → contract, direct award share; procurements by stage; notices by type |

Every page has the same header and Market / Sector / Buyer slicers, synced across pages. The date table filters each fact on its own date: notices on published date, awards on award date, procurements on first notice date.

## Open and connect

1. Power BI Desktop (Windows), recent version. If asked, enable *Options > Preview features > Power BI Project (.pbip) save option* and *Store reports using enhanced metadata format (PBIR)*.
2. Install [DM Sans](https://fonts.google.com/specimen/DM+Sans) on Windows (see [Theme](#theme)).
3. Open `powerbi/UkTenders.pbip`. *Transform data > Edit parameters*: set `SnowflakeServer` to `<orgname>-<accountname>.snowflakecomputing.com`; the rest default to `TENDER_WH`, `TENDER_TRANSFORM`, `TENDER_DB`, `DEV_MARTS`.
4. *Refresh*; sign in to Snowflake when asked.
5. Save. Review the changed `.tmdl` / `.json` files in git before committing; `cache.abf` stays local.

For the published report, set `SnowflakeSchema` to `MARTS`. A read-only reporting role (instead of `TENDER_TRANSFORM`) is a follow-up.

## Editing as code

- Measures, columns, relationships: edit `tables/*.tmdl` / `relationships.tmdl`. TMDL is indented with tabs.
- Visuals: edit `visual.json`; each starts with a `$schema` URL, so VS Code validates and autocompletes it. Fields are referenced by table and name as shown in the model (e.g. `Awards` / `Awarded Value`).
- Close and reopen the project in Desktop after editing files outside it; Desktop does not watch for changes.

## Theme

Colours and font are taken from [hippodigital.co.uk](https://hippodigital.co.uk) (its stylesheet, October 2026).

**Font: DM Sans** (Google Fonts, open licence): a geometric sans with a modern, friendly feel that stays crisp at small sizes. The theme falls back to Segoe UI where DM Sans is not installed. Power BI Service only renders a fixed set of fonts, so the published report shows Segoe UI unless viewers have DM Sans installed; Desktop and PDF exports from Desktop use DM Sans.

| Role | Colour | Hex |
|---|---|---|
| Ink, headers, first series | Navy | `#0C2340` |
| Accent (header subtitle, card bar, table accent) | Pink | `#E07FA3` |
| Series 2–4 | Pink, light blue, teal | `#E07FA3`, `#A5D0FF`, `#4F9B8D` |
| Series 5–8 (avoid if possible) | Dark pink, mid blue, mint, dark green | `#B8577B`, `#6699CC`, `#A0F5E7`, `#002F26` |
| Secondary text | Slate (navy tint) | `#4B5B70` |
| Page background | Hippo light grey | `#EFF2F2` |
| Visual background / border | White / Hippo grey | `#FFFFFF` / `#DDE4E6` |
| Good / neutral / bad | Teal / yellow / dark pink | `#4F9B8D` / `#FFC42E` / `#B8577B` |

What keeps it from looking generic: a navy header band with a pink subtitle, light grey canvas with white rounded cards, navy single-colour bars (one colour per chart unless the colour means something), and a pink accent bar on KPI cards.

Checked with a colour-vision validator: the first four series (navy, pink, light blue, teal) stay distinguishable for colour-blind readers in that order; beyond four they don't, so split the chart or group into "Other". Pink and light blue are low contrast on white (2.6:1, 1.6:1): keep data labels on, never use them for text. `#B8577B` on white is 4.48:1, just under the 4.5:1 text minimum, so small text uses navy or slate.
