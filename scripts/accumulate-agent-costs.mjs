#!/usr/bin/env node
/**
 * accumulate-agent-costs.mjs
 *
 * Merges current live session cost data from agents/<agentId>/sessions/<sessionId>.jsonl into a
 * persistent JSON accumulator file. The accumulator survives container restarts
 * and redeploys; each session is keyed by sessionId so records are never
 * double-counted even if the same session file is scanned multiple times.
 *
 * Usage:
 *   node scripts/accumulate-agent-costs.mjs --history <path>
 *
 * The history file will be created if it does not yet exist.
 */

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
  const args = { history: null };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === "--history") {
      args.history = argv[++i] || null;
    } else if (token === "-h" || token === "--help") {
      console.log("Usage: node scripts/accumulate-agent-costs.mjs --history <path>");
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${token}`);
    }
  }
  if (!args.history) {
    throw new Error("--history <path> is required");
  }
  return args;
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
      // Ignore malformed lines.
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

async function scanLiveSessions(agentsDir) {
  /** Returns Map<sessionId, sessionRecord> from live JSONL files. */
  const live = new Map();

  let agentNames = [];
  try {
    const children = await fs.readdir(agentsDir, { withFileTypes: true });
    agentNames = children.filter((d) => d.isDirectory()).map((d) => d.name).sort();
  } catch {
    return live;
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

      live.set(sessionId, {
        agentId,
        sessionId,
        model: model || "unknown",
        startedAt,
        endedAt,
        assistantTurns,
        tokensTotal,
        costTotal,
        lastScannedAt: new Date().toISOString(),
      });
    }
  }

  return live;
}

async function loadHistory(historyPath) {
  /** Returns Map<sessionId, sessionRecord> from the JSON accumulator file. */
  try {
    const raw = await fs.readFile(historyPath, "utf8");
    const parsed = JSON.parse(raw);
    const sessions = parsed?.sessions;
    if (sessions && typeof sessions === "object") {
      return new Map(Object.entries(sessions));
    }
  } catch {
    // File missing or corrupt — start fresh.
  }
  return new Map();
}

async function writeHistory(historyPath, merged) {
  const sessions = Object.fromEntries(
    [...merged.entries()].sort(([a], [b]) => a.localeCompare(b))
  );
  const payload = {
    version: 1,
    updatedAt: new Date().toISOString(),
    sessions,
  };
  await fs.mkdir(path.dirname(historyPath), { recursive: true });
  await fs.writeFile(historyPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const historyPath = path.isAbsolute(args.history)
    ? args.history
    : path.join(process.cwd(), args.history);

  const openclawRoot = getOpenClawRoot();
  const agentsDir = path.join(openclawRoot, "agents");

  const [history, live] = await Promise.all([
    loadHistory(historyPath),
    scanLiveSessions(agentsDir),
  ]);

  let added = 0;
  let updated = 0;

  for (const [sessionId, liveRecord] of live.entries()) {
    if (history.has(sessionId)) {
      // Update if live session has grown (more assistant turns than history).
      const existing = history.get(sessionId);
      if (liveRecord.assistantTurns > existing.assistantTurns) {
        history.set(sessionId, liveRecord);
        updated += 1;
      }
    } else {
      history.set(sessionId, liveRecord);
      added += 1;
    }
  }

  await writeHistory(historyPath, history);

  console.log(`Wrote: ${historyPath}`);
  console.log(`Sessions in history: ${history.size} (added: ${added}, updated: ${updated})`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
