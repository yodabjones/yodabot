# yodabot

Automated AI report publishing for downstream web ingestion.

[![Latest Report](https://img.shields.io/badge/latest-report-blue)](reports/ai/latest.md)
[![Reports](https://img.shields.io/badge/archive-reports%2Fai-informational)](reports/ai)
[![Docs Hub](https://img.shields.io/badge/docs-hub-success)](docs/README.md)
[![Archive Index](https://img.shields.io/badge/archive-index-lightgrey)](docs/ARCHIVE.md)

This repository is the delivery target for bot-generated report artifacts.
It is designed to be simple, stable, and easy to browse in GitHub.

## Quick Links

- Latest AI report: [reports/ai/latest.md](reports/ai/latest.md)
- AI report archive: [reports/ai](reports/ai)
- Docs hub: [docs/README.md](docs/README.md)
- Delivery operations: [docs/OPERATIONS.md](docs/OPERATIONS.md)
- Editorial and verification policy: [docs/STYLE.md](docs/STYLE.md)
- Archive index page: [docs/ARCHIVE.md](docs/ARCHIVE.md)
- Agent session cost dashboard: [reports/ai/agent-session-costs.html](reports/ai/agent-session-costs.html)

## What This Repo Contains

- A rolling latest report at [reports/ai/latest.md](reports/ai/latest.md)
- A chronological article archive dataset at [reports/ai/article-archive.tsv](reports/ai/article-archive.tsv)
- A browser archive page generated from article history at [reports/ai/index.html](reports/ai/index.html)
- An agent session cost dashboard generated from local session usage records at [reports/ai/agent-session-costs.html](reports/ai/agent-session-costs.html)
- Operational docs for generation, delivery, and troubleshooting in [docs/README.md](docs/README.md)

## How To Read Reports

Reports are usually organized into four core sections:

- Model Releases
- Revenue and Fiscal Signals
- Infrastructure and Data Centers
- Ecosystem and Policy

If a statement is marked [UNVERIFIED], it is a discovery signal that still needs additional confirmation.

## Publish Pipeline

1. Research agent gathers and structures source data.
2. Writer agent formats and synthesizes the report.
3. Sender agent delivers to Telegram and this repository.

For operational details, see [docs/OPERATIONS.md](docs/OPERATIONS.md).

## For Web Ingestion

Use [reports/ai/latest.md](reports/ai/latest.md) as the canonical current artifact.
Use [reports/ai/article-archive.tsv](reports/ai/article-archive.tsv) for historical links and summaries.

## Browser Preview

Suggested landing layout for a simple web renderer:

1. Header row: title, generated timestamp, and verification summary.
2. Summary block: BLUF and top 3 updates.
3. Four report sections: model, revenue, infrastructure, ecosystem.
4. Footer: source count, unverified count, and link back to archive.

For navigation-first browsing in GitHub, use [docs/README.md](docs/README.md) and [docs/ARCHIVE.md](docs/ARCHIVE.md).

## Conventions

- Keep report files in UTF-8 markdown.
- Preserve section headings for parser stability.
- Do not remove [UNVERIFIED] tags unless verification is complete.

## Roadmap

- Add tags and filters to the article archive index.
- Add metadata sidecar files for machine parsing.
- Add automated docs validation checks.
