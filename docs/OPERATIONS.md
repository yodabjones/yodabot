# Operations

This document describes how reports are delivered into this repository.

## Delivery Sequence

1. Research agent generates source-backed notes.
2. Writer agent synthesizes and formats final report payload.
3. Sender agent writes report artifacts into this repository.

## GitHub Artifact Layout

- Canonical latest file: [../reports/ai/latest.md](../reports/ai/latest.md)
- Chronological article archive data: [../reports/ai/article-archive.tsv](../reports/ai/article-archive.tsv)
- Browser archive page: [../reports/ai/index.html](../reports/ai/index.html)

## Sender Scripts

From the sender workspace:

- Publish report to GitHub: bash scripts/publish-to-yodabot.sh --report <payload.md> --title "AI report"
- Unified dual-target runner (test): bash scripts/deliver-both.sh --mode test --report <payload.md>
- Unified dual-target runner (live): bash scripts/deliver-both.sh --mode live --report <payload.md>

## Safety Model

- Fail closed if repository index is already staged.
- Fail closed if repository working tree has unstaged changes.
- Keep commit scope to report artifacts only.

## Troubleshooting

- If push fails due to identity, configure local git identity in the clone.
- If push fails due to branch protection, use an allowed branch or adjust policy.
- If reports are missing, verify writer handoff payload path and sender logs.
