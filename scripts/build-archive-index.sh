#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/ai"
OUT_FILE="$ROOT_DIR/docs/ARCHIVE.md"

mkdir -p "$ROOT_DIR/docs"

{
  echo "# Report Archive Index"
  echo
  echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%SZ")"
  echo
  echo "Use this page for browser-friendly navigation across historical report snapshots."
  echo
  echo "- Latest report: [../reports/ai/latest.md](../reports/ai/latest.md)"
  echo
} > "$OUT_FILE"

mapfile -t files < <(find "$REPORT_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'latest.md' -printf '%f\n' | sort -r)

if [[ ${#files[@]} -eq 0 ]]; then
  {
    echo "## No Archived Reports"
    echo
    echo "No timestamped report files found under [../reports/ai](../reports/ai)."
  } >> "$OUT_FILE"
  exit 0
fi

current_month=""
for f in "${files[@]}"; do
  month="${f:0:7}"
  if [[ "$month" != "$current_month" ]]; then
    current_month="$month"
    {
      echo "## $current_month"
      echo
    } >> "$OUT_FILE"
  fi

  {
    echo "- [../reports/ai/$f](../reports/ai/$f)"
  } >> "$OUT_FILE"
done

echo "Wrote $OUT_FILE"
