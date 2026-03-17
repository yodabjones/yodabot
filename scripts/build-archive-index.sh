#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports/ai"
OUT_FILE="$ROOT_DIR/docs/ARCHIVE.md"
OUT_HTML="$ROOT_DIR/reports/ai/index.html"
ARCHIVE_DATA="$ROOT_DIR/reports/ai/article-archive.tsv"
OUT_TAG_INDEX="$ROOT_DIR/reports/ai/tag-index.json"

mkdir -p "$ROOT_DIR/docs"

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

extract_article_tags() {
  local summary="$1"
  local url="$2"

  node - "$summary" "$url" <<'NODE'
const summary = process.argv[2] || "";
const url = process.argv[3] || "";

const tags = new Set();
const add = (value) => {
  const v = (value || "").replace(/\s+/g, " ").trim();
  if (!v) return;
  if (v.length < 2 || v.length > 48) return;
  tags.add(v);
};

const lower = summary.toLowerCase();
const topicMap = [
  ["infrastructure", ["infrastructure", "data center", "datacenter", "power", "grid", "cooling", "facility"]],
  ["model", ["model", "release", "llm", "foundation model", "reasoning"]],
  ["revenue", ["revenue", "earnings", "qoq", "guidance", "capex", "contract"]],
  ["regulation", ["regulation", "regulatory", "doj", "ftc", "eu", "cma", "lawsuit"]],
  ["policy", ["policy", "export control", "antitrust", "compliance"]],
  ["gpu", ["gpu", "chip", "accelerator", "cuda", "h100", "b200", "rubin"]],
  ["cloud", ["cloud", "azure", "aws", "gcp", "hosting"]],
  ["funding", ["funding", "raise", "valuation", "series", "investment"]],
  ["acquisition", ["acquire", "acquisition", "merger", "m&a"]],
];

for (const [topic, keys] of topicMap) {
  if (keys.some((k) => lower.includes(k))) add(topic);
}

try {
  const host = new URL(url).hostname.replace(/^www\./, "");
  add(host);
  for (const part of host.split(".")) {
    if (part && !["com", "org", "net", "co", "io", "ai", "gov"].includes(part)) add(part);
  }
} catch {}

for (const m of summary.matchAll(/\b[A-Z]{2,}(?:\.[A-Z]{2,})?\b/g)) add(m[0]);

const stop = new Set([
  "The", "A", "An", "And", "Or", "For", "With", "From", "In", "On", "At", "By", "To", "Of", "Latest", "Report", "Open", "Source"
]);
for (const m of summary.matchAll(/\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})\b/g)) {
  const phrase = m[1].trim();
  const parts = phrase.split(/\s+/);
  if (parts.every((p) => stop.has(p))) continue;
  add(phrase);
}

process.stdout.write(Array.from(tags).sort((a, b) => a.localeCompare(b)).join("|"));
NODE
}

build_tag_index_json() {
  local archive_tsv="$1"
  local out_json="$2"

  node - "$archive_tsv" "$out_json" <<'NODE'
const fs = require("fs");

const archivePath = process.argv[2];
const outPath = process.argv[3];

function extractArticleTags(summary, url) {
  const tags = new Set();
  const add = (value) => {
    const v = (value || "").replace(/\s+/g, " ").trim();
    if (!v) return;
    if (v.length < 2 || v.length > 48) return;
    tags.add(v);
  };

  const lower = (summary || "").toLowerCase();
  const topicMap = [
    ["infrastructure", ["infrastructure", "data center", "datacenter", "power", "grid", "cooling", "facility"]],
    ["model", ["model", "release", "llm", "foundation model", "reasoning"]],
    ["revenue", ["revenue", "earnings", "qoq", "guidance", "capex", "contract"]],
    ["regulation", ["regulation", "regulatory", "doj", "ftc", "eu", "cma", "lawsuit"]],
    ["policy", ["policy", "export control", "antitrust", "compliance"]],
    ["gpu", ["gpu", "chip", "accelerator", "cuda", "h100", "b200", "rubin"]],
    ["cloud", ["cloud", "azure", "aws", "gcp", "hosting"]],
    ["funding", ["funding", "raise", "valuation", "series", "investment"]],
    ["acquisition", ["acquire", "acquisition", "merger", "m&a"]],
  ];

  for (const [topic, keys] of topicMap) {
    if (keys.some((k) => lower.includes(k))) add(topic);
  }

  try {
    const host = new URL(url).hostname.replace(/^www\./, "");
    add(host);
    for (const part of host.split(".")) {
      if (part && !["com", "org", "net", "co", "io", "ai", "gov"].includes(part)) add(part);
    }
  } catch {}

  for (const m of (summary || "").matchAll(/\b[A-Z]{2,}(?:\.[A-Z]{2,})?\b/g)) add(m[0]);

  const stop = new Set(["The", "A", "An", "And", "Or", "For", "With", "From", "In", "On", "At", "By", "To", "Of", "Latest", "Report", "Open", "Source"]);
  for (const m of (summary || "").matchAll(/\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})\b/g)) {
    const phrase = m[1].trim();
    const parts = phrase.split(/\s+/);
    if (parts.every((p) => stop.has(p))) continue;
    add(phrase);
  }

  return Array.from(tags).sort((a, b) => a.localeCompare(b));
}

const lines = fs.existsSync(archivePath) ? fs.readFileSync(archivePath, "utf8").split(/\r?\n/).filter(Boolean) : [];
const articles = [];
const tagToArticleIds = {};

for (let i = 0; i < lines.length; i += 1) {
  const cols = lines[i].split("\t");
  if (cols.length < 4) continue;

  const [epoch, stamp, summary, url] = cols;
  const tagsRaw = cols.slice(4).join("\t");
  const tags = tagsRaw ? tagsRaw.split("|").map((t) => t.trim()).filter(Boolean) : extractArticleTags(summary, url);
  const id = `a${i + 1}`;

  articles.push({ id, epoch: Number(epoch) || 0, stamp, summary, url, tags });
  for (const tag of tags) {
    if (!tagToArticleIds[tag]) tagToArticleIds[tag] = [];
    tagToArticleIds[tag].push(id);
  }
}

const orderedTagMap = Object.fromEntries(Object.entries(tagToArticleIds).sort((a, b) => a[0].localeCompare(b[0])));
const payload = {
  version: 1,
  generatedAt: new Date().toISOString(),
  articleCount: articles.length,
  tagCount: Object.keys(orderedTagMap).length,
  articles,
  tagToArticleIds: orderedTagMap,
};

fs.writeFileSync(outPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
NODE
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
  cat > "$OUT_TAG_INDEX" <<'JSON'
{
  "version": 1,
  "generatedAt": "",
  "articleCount": 0,
  "tagCount": 0,
  "articles": [],
  "tagToArticleIds": {}
}
JSON

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
    .summary {
      color: var(--ink);
      margin-bottom: 0.25rem;
    }
    .tag-list {
      display: flex;
      gap: 0.35rem;
      flex-wrap: wrap;
    }
    .tag {
      border: 1px solid #c8d8e6;
      background: #f4f9ff;
      color: #36546b;
      border-radius: 999px;
      padding: 0.12rem 0.48rem;
      font-size: 0.74rem;
      font-weight: 700;
    }
    .search-row {
      display: block;
      padding: 0.75rem 1rem;
      border-top: 1px solid var(--line);
      background: #f9fcff;
    }
    .search-row input {
      width: 100%;
      border: 1px solid #c5dbef;
      border-radius: 10px;
      padding: 0.5rem 0.65rem;
      font: inherit;
      margin-bottom: 0.4rem;
    }
    .search-row .hint {
      color: var(--muted);
      font-size: 0.82rem;
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
  echo "Wrote $OUT_TAG_INDEX"
  exit 0
fi

build_tag_index_json "$ARCHIVE_DATA" "$OUT_TAG_INDEX"

current_month=""
while IFS=$'\t' read -r _epoch stamp summary url tags; do
  [[ -z "$stamp" || -z "$summary" || -z "$url" ]] && continue
  if [[ -z "${tags:-}" ]]; then
    tags="$(extract_article_tags "$summary" "$url")"
  fi
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
    echo "  - tags: ${tags//|/, }"
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
      <div class="search-row">
        <input id="tag-query" type="text" list="tag-options" placeholder="Search tags (comma-separated, e.g. OpenAI, infrastructure, FTC)" />
        <datalist id="tag-options"></datalist>
        <div id="filter-hint" class="hint">Showing all archived articles.</div>
      </div>
HTML_HEAD

  current_month=""
  article_id_counter=0
  while IFS=$'\t' read -r _epoch stamp summary url tags; do
    [[ -z "$stamp" || -z "$summary" || -z "$url" ]] && continue
    article_id_counter=$((article_id_counter + 1))
    article_id="a${article_id_counter}"
    if [[ -z "${tags:-}" ]]; then
      tags="$(extract_article_tags "$summary" "$url")"
    fi
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
    safe_tags_attr="$(printf '%s' "$tags" | html_escape)"
    {
      echo "      <div class=\"row\" data-entry=\"1\" data-article-id=\"$article_id\" data-month=\"$month\" data-tags=\"$safe_tags_attr\">"
      echo "        <div class=\"ts\">$safe_stamp</div>"
      echo "        <div class=\"label\">"
      echo "          <div class=\"summary\">$safe_summary</div>"
      echo "          <div class=\"tag-list\">"
      IFS='|' read -r -a tag_items <<< "$tags"
      for tag in "${tag_items[@]}"; do
        [[ -z "$tag" ]] && continue
        safe_tag="$(printf '%s' "$tag" | html_escape)"
        echo "            <span class=\"tag\">$safe_tag</span>"
      done
      echo "          </div>"
      echo "        </div>"
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
      const pager = document.getElementById('pager');
      const meta = document.getElementById('pager-meta');
      const prev = document.getElementById('prev-page');
      const next = document.getElementById('next-page');
      const monthRows = Array.from(document.querySelectorAll('.month-row[data-month]'));
      const queryInput = document.getElementById('tag-query');
      const options = document.getElementById('tag-options');
      const hint = document.getElementById('filter-hint');
      const entryById = new Map(entries.map((row) => [row.getAttribute('data-article-id'), row]));
      let indexMap = null;

      const hydrateTagOptions = (tags) => {
        options.innerHTML = '';
        tags.forEach((tag) => {
          const opt = document.createElement('option');
          opt.value = tag;
          options.appendChild(opt);
        });
      };

      const localTags = new Set();
      entries.forEach((row) => {
        const tags = (row.getAttribute('data-tags') || '').split('|').map((t) => t.trim()).filter(Boolean);
        tags.forEach((t) => localTags.add(t));
      });
      hydrateTagOptions(Array.from(localTags).sort((a, b) => a.localeCompare(b)));

      fetch('./tag-index.json', { cache: 'no-cache' })
        .then((resp) => (resp.ok ? resp.json() : null))
        .then((data) => {
          if (!data || !data.tagToArticleIds) return;
          indexMap = data.tagToArticleIds;
          hydrateTagOptions(Object.keys(indexMap).sort((a, b) => a.localeCompare(b)));
          render();
        })
        .catch(() => {
          // Keep local fallback behavior when index is unavailable.
        });

      let page = 0;
      let filtered = entries;

      const parseQueryTags = () => {
        return (queryInput.value || '')
          .split(',')
          .map((v) => v.trim().toLowerCase())
          .filter(Boolean);
      };

      const applyFilter = () => {
        const active = parseQueryTags();
        if (active.length === 0) {
          filtered = entries;
          hint.textContent = 'Showing all archived articles.';
          return;
        }

        if (indexMap) {
          const tagEntries = Object.entries(indexMap);
          let candidateIds = null;

          active.forEach((query) => {
            const idsForQuery = new Set();
            tagEntries.forEach(([tag, ids]) => {
              if (tag.toLowerCase().includes(query)) {
                ids.forEach((id) => idsForQuery.add(id));
              }
            });
            if (candidateIds === null) {
              candidateIds = idsForQuery;
            } else {
              candidateIds = new Set(Array.from(candidateIds).filter((id) => idsForQuery.has(id)));
            }
          });

          const idSet = candidateIds || new Set();
          filtered = entries.filter((row) => idSet.has(row.getAttribute('data-article-id')));
        } else {
          filtered = entries.filter((row) => {
            const rowTags = (row.getAttribute('data-tags') || '').toLowerCase().split('|');
            return active.every((q) => rowTags.some((tag) => tag.includes(q)));
          });
        }

        hint.textContent = `Filter active: ${active.join(', ')} • ${filtered.length} matches`;
      };

      const render = () => {
        applyFilter();
        const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
        if (page >= totalPages) page = totalPages - 1;
        const start = page * pageSize;
        const end = start + pageSize;
        const visibleMonths = new Set();

        entries.forEach((row) => {
          row.style.display = 'none';
        });

        filtered.forEach((row, idx) => {
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

        meta.textContent = `Page ${page + 1} of ${totalPages} • ${filtered.length} matching archived articles`;
        prev.disabled = page === 0;
        next.disabled = page >= totalPages - 1;
        pager.classList.toggle('hidden', filtered.length <= pageSize);
      };

      prev.addEventListener('click', () => {
        if (page > 0) {
          page -= 1;
          render();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }
      });
      next.addEventListener('click', () => {
        const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
        if (page < totalPages - 1) {
          page += 1;
          render();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }
      });
      queryInput.addEventListener('input', () => {
        page = 0;
        render();
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
echo "Wrote $OUT_TAG_INDEX"
