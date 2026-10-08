# Diagrams

Every diagram of the system, as [Mermaid](https://mermaid.js.org) in Markdown, so GitHub renders them and changes are reviewed as text. Keep them in step with the code (rule in `CLAUDE.md`). What each one answers, in reading order: [architecture.md](../architecture.md).

| File | Diagrams |
|---|---|
| [c4.md](c4.md) | System context, containers, dbt project components, deployment |
| [flows.md](flows.md) | Notice to dashboard, daily schedule, one ingest run, dbt run and alerts, change to production |
| [data.md](data.md) | Layers and grain, dbt lineage |
| [staging-erd.md](staging-erd.md) | Raw tables and staging models: keys and relationships |
| [marts-erd.md](marts-erd.md) | The star schema Power BI reads |
| [security.md](security.md) | Users, roles and what each may touch |
| [lifecycle.md](lifecycle.md) | A procurement in the model, scheduled task states |

To preview locally: VS Code's Markdown preview (Ctrl+Shift+V) with a Mermaid extension, or `npx -y @mermaid-js/mermaid-cli -i <file>.md -o out.md` to render each diagram to SVG.
