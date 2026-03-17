#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/ai"
OUT_FILE="$ROOT_DIR/docs/ARCHIVE.md"
OUT_HTML="$ROOT_DIR/reports/ai/index.html"
ARCHIVE_DATA="$ROOT_DIR/reports/ai/article-archive.tsv"

mkdir -p "$ROOT_DIR/docs"

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

{
  echo "# Article Archive Index"
  echo
  echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%SZ")"
  echo
  echo "This index tracks previously reported article links and summaries in reverse chronological order."
  echo
  echo "- Latest report: [../reports/ai/latest.md](../reports/ai/latest.md)"
  echo "- Archive data source: [../reports/ai/article-archive.tsv](../reports/ai/article-archive.tsv)"
  echo
} > "$OUT_FILE"

if [[ ! -s "$ARCHIVE_DATA" ]]; then
  {
    echo "## No Archived Articles"
    echo
    echo "No article entries found in [../reports/ai/article-archive.tsv](../reports/ai/article-archive.tsv)."
  } >> "$OUT_FILE"

  {
    cat <<'HTML_HEAD'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AI Article Archive</title>
  <meta name="description" content="Chronological archive of previously reported AI article links and summaries" />
  <style>
    :root {
      --bg: #eef4fb;
      --panel: #ffffff;
      --ink: #172333;
      --muted: #5c6979;
      --line: #d4dee8;
      --accent: #0f5f89;
      --accent-soft: #e4f3ff;
    }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      background: radial-gradient(circle at 12% 0%, #d9f0ff 0, rgba(217,240,255,0) 42%), var(--bg);
      color: var(--ink);
      font: 16px/1.5 "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
    }
    .shell {
      width: min(980px, 100% - 2rem);
      margin: 1rem auto 2rem;
    }
    .hero,
    .card {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 14px;
      box-shadow: 0 10px 24px rgba(17, 30, 43, 0.06);
    }
    .hero {
      padding: 1rem 1.2rem;
      margin-bottom: 0.85rem;
    }
    .hero h1 {
      margin: 0;
      font-size: clamp(1.3rem, 3.3vw, 1.95rem);
    }
    .hero p {
      margin: 0.35rem 0 0;
      color: var(--muted);
    }
    .hero a {
      color: var(--accent);
      font-weight: 700;
      text-decoration: none;
    }
    .card {
      padding: 0.3rem 0;
      overflow: hidden;
    }
    .month-row {
      padding: 0.45rem 1rem;
      border-top: 1px solid var(--line);
      background: #f6fbff;
      color: #0d3c5a;
      font-size: 0.8rem;
      font-weight: 800;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }
    .row {
      display: grid;
      grid-template-columns: minmax(180px, 280px) 1fr auto;
      gap: 0.8rem;
      align-items: center;
      padding: 0.62rem 1rem;
      border-top: 1px solid var(--line);
    }
    .row:first-child {
      border-top: 0;
    }
    .ts {
      font-weight: 700;
      color: #102a43;
      white-space: nowrap;
    }
    .label {
      color: var(--muted);
    }
    .actions {
      display: flex;
      gap: 0.5rem;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    .actions a {
      color: var(--accent);
      text-decoration: none;
      border: 1px solid #c5dbef;
      background: var(--accent-soft);
      border-radius: 999px;
      padding: 0.25rem 0.62rem;
      font-size: 0.88rem;
      font-weight: 700;
    }
    .domain {
      border: 1px solid #c2d8ea;
      background: #f7fbff;
      color: #33536a;
      border-radius: 999px;
      padding: 0.23rem 0.55rem;
      font-size: 0.78rem;
      font-weight: 700;
    }
    .pager {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.6rem;
      border-top: 1px solid var(--line);
      padding: 0.65rem 1rem;
      background: #f8fcff;
    }
    .pager.hidden { display: none; }
    .pager .meta {
      color: var(--muted);
      font-size: 0.9rem;
      font-weight: 600;
    }
    .pager .controls {
      display: flex;
      gap: 0.5rem;
      align-items: center;
    }
    .pager button {
      border: 1px solid #c5dbef;
      background: var(--accent-soft);
      color: var(--accent);
      font-weight: 700;
      border-radius: 999px;
      padding: 0.28rem 0.7rem;
      cursor: pointer;
    }
    .pager button:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    @media (max-width: 720px) {
      .row {
        grid-template-columns: 1fr;
        gap: 0.45rem;
      }
      .actions {
        justify-content: flex-start;
      }
      .ts {
        white-space: normal;
      }
      .pager {
        flex-direction: column;
        align-items: stretch;
      }
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <h1>AI Article Archive</h1>
      <p>Chronological feed of previously reported article links and summaries. <a href="/">Go to landing page</a>.</p>
    </section>
    <section class="card">
      <div class="row">
        <div class="ts">Latest report</div>
        <div class="label">Current report endpoint (not part of archive)</div>
        <div class="actions">
          <a href="./latest.html">HTML</a>
          <a href="./latest.md">Markdown</a>
        </div>
      </div>
      <div class="row">
        <div class="ts">No archived entries</div>
        <div class="label">Older article links and summaries will appear here after the next publish cycle.</div>
        <div class="actions"></div>
      </div>
    </section>
  </main>
</body>
</html>
HTML_HEAD
  } > "$OUT_HTML"

  echo "Wrote $OUT_FILE"
  echo "Wrote $OUT_HTML"
  exit 0
fi

current_month=""
while IFS=$'\t' read -r _epoch stamp summary url; do
  [[ -z "$stamp" || -z "$summary" || -z "$url" ]] && continue
  month="${stamp:0:7}"
  if [[ "$month" != "$current_month" ]]; then
    current_month="$month"
    {
      echo "## $current_month"
      echo
    } >> "$OUT_FILE"
  fi

  {
    echo "- $stamp - $summary"
    echo "  - <$url>"
  } >> "$OUT_FILE"
done < "$ARCHIVE_DATA"

{
  cat <<'HTML_HEAD'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AI Article Archive</title>
  <meta name="description" content="Chronological archive of previously reported AI article links and summaries" />
  <style>
    :root {
      --bg: #eef4fb;
      --panel: #ffffff;
      --ink: #172333;
      --muted: #5c6979;
      --line: #d4dee8;
      --accent: #0f5f89;
      --accent-soft: #e4f3ff;
    }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      background: radial-gradient(circle at 12% 0%, #d9f0ff 0, rgba(217,240,255,0) 42%), var(--bg);
      color: var(--ink);
      font: 16px/1.5 "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
    }
    .shell {
      width: min(980px, 100% - 2rem);
      margin: 1rem auto 2rem;
    }
    .hero,
    .card {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 14px;
      box-shadow: 0 10px 24px rgba(17, 30, 43, 0.06);
    }
    .hero {
      padding: 1rem 1.2rem;
      margin-bottom: 0.85rem;
    }
    .hero h1 {
      margin: 0;
      font-size: clamp(1.3rem, 3.3vw, 1.95rem);
    }
    .hero p {
      margin: 0.35rem 0 0;
      color: var(--muted);
    }
    .hero a {
      color: var(--accent);
      font-weight: 700;
      text-decoration: none;
    }
    .card {
      padding: 0.3rem 0;
      overflow: hidden;
    }
    .row {
      display: grid;
      grid-template-columns: minmax(180px, 280px) 1fr auto;
      gap: 0.8rem;
      align-items: center;
      padding: 0.75rem 1rem;
      border-top: 1px solid var(--line);
    }
    .row:first-child {
      border-top: 0;
    }
    .ts {
      font-weight: 700;
      color: #102a43;
      white-space: nowrap;
    }
    .label {
      color: var(--muted);
    }
    .actions {
      display: flex;
      gap: 0.5rem;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    .actions a {
      color: var(--accent);
      text-decoration: none;
      border: 1px solid #c5dbef;
      background: var(--accent-soft);
      border-radius: 999px;
      padding: 0.25rem 0.62rem;
      font-size: 0.88rem;
      font-weight: 700;
    }
    @media (max-width: 720px) {
      .row {
        grid-template-columns: 1fr;
        gap: 0.45rem;
      }
      .actions {
        justify-content: flex-start;
      }
      .ts {
        white-space: normal;
      }
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <h1>AI Article Archive</h1>
      <p>Chronological feed of previously reported article links and summaries. <a href="/">Go to landing page</a>.</p>
    </section>
    <section class="card">
      <div class="row">
        <div class="ts">Latest report</div>
        <div class="label">Current report endpoint (not part of archive)</div>
        <div class="actions">
          <a href="./latest.html">HTML</a>
          <a href="./latest.md">Markdown</a>
        </div>
      </div>
HTML_HEAD

  current_month=""
  while IFS=$'\t' read -r _epoch stamp summary url; do
    [[ -z "$stamp" || -z "$summary" || -z "$url" ]] && continue
    month="${stamp:0:7}"
    if [[ "$month" != "$current_month" ]]; then
      current_month="$month"
      echo "      <div class=\"month-row\" data-month=\"$month\">$month</div>"
    fi

    domain="${url#*://}"
    domain="${domain%%/*}"
    domain="${domain#www.}"
    safe_stamp="$(printf '%s' "$stamp" | html_escape)"
    safe_summary="$(printf '%s' "$summary" | html_escape)"
    safe_url="$(printf '%s' "$url" | html_escape)"
    safe_domain="$(printf '%s' "$domain" | html_escape)"
    {
      echo "      <div class=\"row\" data-entry=\"1\" data-month=\"$month\">"
      echo "        <div class=\"ts\">$safe_stamp</div>"
      echo "        <div class=\"label\">$safe_summary</div>"
      echo "        <div class=\"actions\">"
      echo "          <span class=\"domain\">$safe_domain</span>"
      echo "          <a href=\"$safe_url\" target=\"_blank\" rel=\"noopener noreferrer\">Open source</a>"
      echo "        </div>"
      echo "      </div>"
    }
  done < "$ARCHIVE_DATA"

  cat <<'HTML_FOOT'
      <div id="pager" class="pager hidden">
        <div id="pager-meta" class="meta"></div>
        <div class="controls">
          <button id="prev-page" type="button">Previous</button>
          <button id="next-page" type="button">Next</button>
        </div>
      </div>
    </section>
  </main>
  <script>
    (() => {
      const pageSize = 12;
      const entries = Array.from(document.querySelectorAll('.row[data-entry="1"]'));
      if (entries.length <= pageSize) return;

      const pager = document.getElementById('pager');
      const meta = document.getElementById('pager-meta');
      const prev = document.getElementById('prev-page');
      const next = document.getElementById('next-page');
      const monthRows = Array.from(document.querySelectorAll('.month-row[data-month]'));
      const totalPages = Math.ceil(entries.length / pageSize);
      let page = 0;

      const render = () => {
        const start = page * pageSize;
        const end = start + pageSize;
        const visibleMonths = new Set();

        entries.forEach((row, idx) => {
          const show = idx >= start && idx < end;
          row.style.display = show ? '' : 'none';
          if (show) {
            visibleMonths.add(row.getAttribute('data-month'));
          }
        });

        monthRows.forEach((row) => {
          const month = row.getAttribute('data-month');
          row.style.display = visibleMonths.has(month) ? '' : 'none';
        });

        meta.textContent = `Page ${page + 1} of ${totalPages} • ${entries.length} archived articles`;
        prev.disabled = page === 0;
        next.disabled = page >= totalPages - 1;
      };

      pager.classList.remove('hidden');
      prev.addEventListener('click', () => {
        if (page > 0) {
          page -= 1;
          render();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }
      });
      next.addEventListener('click', () => {
        if (page < totalPages - 1) {
          page += 1;
          render();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }
      });

      render();
    })();
  </script>
</body>
</html>
HTML_FOOT
} > "$OUT_HTML"

echo "Wrote $OUT_FILE"
echo "Wrote $OUT_HTML"
