#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";

function getOpenClawRoot() {
  if (process.env.OPENCLAW_ROOT && String(process.env.OPENCLAW_ROOT).trim()) {
    return path.resolve(process.env.OPENCLAW_ROOT);
  }
  // scripts/ -> yodabot/ -> repos/ -> sender/ -> agents/ -> workspace/ -> .openclaw/
  return path.resolve(import.meta.dirname, "../../../../../..");
}

function parseArgs(argv) {
  const args = {
    output: null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === "--output") {
      args.output = argv[++i] || null;
    } else if (token === "-h" || token === "--help") {
      console.log("Usage: node scripts/build-agent-session-costs.mjs [--output <path>]");
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${token}`);
    }
  }

  return args;
}

function esc(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function fmtMoney(value) {
  if (!Number.isFinite(value)) return "$0.000000";
  return `$${value.toFixed(6)}`;
}

function fmtInt(value) {
  if (!Number.isFinite(value)) return "0";
  return Math.round(value).toLocaleString("en-US");
}

async function safeReadJsonLines(filePath) {
  const raw = await fs.readFile(filePath, "utf8");
  const out = [];
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      out.push(JSON.parse(trimmed));
    } catch {
      // Ignore malformed lines so one bad record does not break reporting.
    }
  }
  return out;
}

function isAssistantUsageRecord(evt) {
  return (
    evt &&
    evt.type === "message" &&
    evt.message &&
    evt.message.role === "assistant" &&
    evt.message.usage &&
    evt.message.usage.cost &&
    typeof evt.message.usage.cost.total === "number"
  );
}

function buildHtml({ generatedAtIso, openclawRoot, sessions, totalsByAgent, grandTotal }) {
  const sessionRows = sessions
    .map((s) => {
      return `<tr>
<td>${esc(s.agentId)}</td>
<td>${esc(s.sessionId)}</td>
<td>${esc(s.model)}</td>
<td>${esc(s.startedAt || "-")}</td>
<td>${esc(s.endedAt || "-")}</td>
<td class="num">${fmtInt(s.assistantTurns)}</td>
<td class="num">${fmtMoney(s.costTotal)}</td>
<td class="num">${fmtInt(s.tokensTotal)}</td>
</tr>`;
    })
    .join("\n");

  const agentRows = [...totalsByAgent.values()]
    .sort((a, b) => b.costTotal - a.costTotal)
    .map((a) => {
      return `<tr>
<td>${esc(a.agentId)}</td>
<td class="num">${fmtInt(a.sessions)}</td>
<td class="num">${fmtInt(a.assistantTurns)}</td>
<td class="num">${fmtMoney(a.costTotal)}</td>
<td class="num">${fmtInt(a.tokensTotal)}</td>
</tr>`;
    })
    .join("\n");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Agent Session Cost Dashboard</title>
  <style>
    :root {
      --bg: #f2f7fa;
      --panel: #ffffff;
      --ink: #17313c;
      --muted: #5e7c89;
      --line: #d5e3ea;
      --accent: #1776a5;
      --chip: #eaf4f9;
    }
    body {
      margin: 0;
      font-family: "Segoe UI", "Helvetica Neue", sans-serif;
      background: radial-gradient(circle at top right, #deedf4 0%, var(--bg) 45%, #eef6fa 100%);
      color: var(--ink);
    }
    .shell {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem 1rem 3rem;
    }
    .hero {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 1.2rem 1.2rem 1rem;
      box-shadow: 0 10px 30px rgba(16, 54, 73, 0.08);
      margin-bottom: 1rem;
    }
    h1 {
      margin: 0 0 0.5rem;
      font-size: 1.6rem;
    }
    p {
      margin: 0.25rem 0;
      color: var(--muted);
    }
    .links {
      display: flex;
      gap: 0.8rem;
      flex-wrap: wrap;
      margin-top: 0.8rem;
    }
    .links a {
      text-decoration: none;
      color: var(--accent);
      background: var(--chip);
      border: 1px solid #cce2ee;
      border-radius: 999px;
      padding: 0.35rem 0.75rem;
      font-size: 0.9rem;
    }
    .grid {
      display: grid;
      gap: 1rem;
    }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 14px;
      overflow: hidden;
      box-shadow: 0 8px 24px rgba(16, 54, 73, 0.06);
    }
    .panel h2 {
      margin: 0;
      padding: 0.8rem 1rem;
      font-size: 1rem;
      border-bottom: 1px solid var(--line);
      background: #f7fbfd;
    }
    .table-wrap {
      overflow: auto;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.9rem;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 0.5rem 0.65rem;
      text-align: left;
      white-space: nowrap;
    }
    th {
      color: var(--muted);
      font-weight: 600;
      background: #fbfdfe;
      position: sticky;
      top: 0;
      z-index: 1;
    }
    td.num {
      text-align: right;
      font-variant-numeric: tabular-nums;
    }
    .totals {
      display: flex;
      gap: 0.75rem;
      flex-wrap: wrap;
      margin-top: 0.8rem;
    }
    .totals span {
      background: #f5fbff;
      border: 1px solid #d4e8f3;
      border-radius: 10px;
      padding: 0.45rem 0.7rem;
      font-size: 0.9rem;
      color: #1d4e63;
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <h1>Agent Session Cost Dashboard</h1>
      <p>Source: local OpenClaw session transcripts under <code>${esc(path.join(openclawRoot, "agents"))}</code>.</p>
      <p>Generated (UTC): ${esc(generatedAtIso)}</p>
      <div class="totals">
        <span>Total sessions: ${fmtInt(grandTotal.sessions)}</span>
        <span>Total assistant turns: ${fmtInt(grandTotal.assistantTurns)}</span>
        <span>Total cost: ${fmtMoney(grandTotal.costTotal)}</span>
        <span>Total tokens: ${fmtInt(grandTotal.tokensTotal)}</span>
      </div>
      <nav class="links" aria-label="cost links">
        <a href="/">Back to latest report</a>
        <a href="/reports/ai/">Open report archive</a>
      </nav>
    </section>

    <section class="grid">
      <article class="panel">
        <h2>By Agent</h2>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Agent</th>
                <th>Sessions</th>
                <th>Assistant turns</th>
                <th>Total cost</th>
                <th>Total tokens</th>
              </tr>
            </thead>
            <tbody>
${agentRows || "<tr><td colspan=\"5\">No cost records found.</td></tr>"}
            </tbody>
          </table>
        </div>
      </article>

      <article class="panel">
        <h2>By Session</h2>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Agent</th>
                <th>Session ID</th>
                <th>Model</th>
                <th>Start</th>
                <th>End</th>
                <th>Assistant turns</th>
                <th>Total cost</th>
                <th>Total tokens</th>
              </tr>
            </thead>
            <tbody>
${sessionRows || "<tr><td colspan=\"8\">No cost records found.</td></tr>"}
            </tbody>
          </table>
        </div>
      </article>
    </section>
  </main>
</body>
</html>`;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const openclawRoot = getOpenClawRoot();
  const agentsDir = path.join(openclawRoot, "agents");
  const outPath = args.output
    ? (path.isAbsolute(args.output) ? args.output : path.join(process.cwd(), args.output))
    : path.join(process.cwd(), "reports/ai/agent-session-costs.html");

  const sessions = [];
  const totalsByAgent = new Map();

  let agentNames = [];
  try {
    const children = await fs.readdir(agentsDir, { withFileTypes: true });
    agentNames = children.filter((d) => d.isDirectory()).map((d) => d.name).sort();
  } catch {
    agentNames = [];
  }

  for (const agentId of agentNames) {
    const sessionsDir = path.join(agentsDir, agentId, "sessions");
    let files = [];
    try {
      files = await fs.readdir(sessionsDir, { withFileTypes: true });
    } catch {
      continue;
    }

    const jsonlFiles = files
      .filter((f) => f.isFile() && f.name.endsWith(".jsonl"))
      .map((f) => path.join(sessionsDir, f.name))
      .sort();

    for (const transcriptPath of jsonlFiles) {
      const sessionId = path.basename(transcriptPath, ".jsonl");
      const events = await safeReadJsonLines(transcriptPath);

      let startedAt = null;
      let endedAt = null;
      let model = "";
      let assistantTurns = 0;
      let tokensTotal = 0;
      let costTotal = 0;

      for (const evt of events) {
        const ts = evt?.timestamp;
        if (typeof ts === "string") {
          if (!startedAt || ts < startedAt) startedAt = ts;
          if (!endedAt || ts > endedAt) endedAt = ts;
        }

        if (!isAssistantUsageRecord(evt)) continue;
        assistantTurns += 1;

        const usage = evt.message.usage;
        tokensTotal += Number(usage.totalTokens || 0);
        costTotal += Number(usage.cost.total || 0);

        if (!model && typeof evt.message.model === "string") {
          model = evt.message.model;
        }
      }

      if (assistantTurns === 0) continue;

      sessions.push({
        agentId,
        sessionId,
        model: model || "unknown",
        startedAt,
        endedAt,
        assistantTurns,
        tokensTotal,
        costTotal,
      });

      const bucket = totalsByAgent.get(agentId) || {
        agentId,
        sessions: 0,
        assistantTurns: 0,
        tokensTotal: 0,
        costTotal: 0,
      };

      bucket.sessions += 1;
      bucket.assistantTurns += assistantTurns;
      bucket.tokensTotal += tokensTotal;
      bucket.costTotal += costTotal;
      totalsByAgent.set(agentId, bucket);
    }
  }

  sessions.sort((a, b) => b.costTotal - a.costTotal);

  const grandTotal = {
    sessions: sessions.length,
    assistantTurns: sessions.reduce((sum, s) => sum + s.assistantTurns, 0),
    tokensTotal: sessions.reduce((sum, s) => sum + s.tokensTotal, 0),
    costTotal: sessions.reduce((sum, s) => sum + s.costTotal, 0),
  };

  const generatedAtIso = new Date().toISOString();
  const html = buildHtml({ generatedAtIso, openclawRoot, sessions, totalsByAgent, grandTotal });

  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, `${html}\n`, "utf8");

  console.log(`Wrote: ${outPath}`);
  console.log(`Sessions included: ${sessions.length}`);
  console.log(`Total cost: ${fmtMoney(grandTotal.costTotal)}`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
