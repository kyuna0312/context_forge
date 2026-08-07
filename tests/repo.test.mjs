// Repo validation suite — zero dependencies, run with: node --test tests/
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");

function walk(dir, ext, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === "node_modules" || e.name === ".git") continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, ext, out);
    else if (e.name.endsWith(ext)) out.push(p);
  }
  return out;
}

function frontmatter(file) {
  const m = fs.readFileSync(file, "utf8").match(/^---\n([\s\S]*?)\n---/);
  assert.ok(m, `${path.relative(root, file)}: missing YAML frontmatter`);
  return m[1];
}

test("every JSON file parses", () => {
  for (const f of walk(root, ".json")) {
    assert.doesNotThrow(
      () => JSON.parse(fs.readFileSync(f, "utf8")),
      `${path.relative(root, f)} is not valid JSON`
    );
  }
});

test("hooks.json: valid events, existing scripts, $CLAUDE_PLUGIN_ROOT paths", () => {
  const VALID = new Set([
    "PreToolUse", "PostToolUse", "SessionStart", "Stop", "SubagentStop",
    "SessionEnd", "UserPromptSubmit", "PreCompact", "Notification",
  ]);
  const cfg = JSON.parse(fs.readFileSync(path.join(root, "hooks/hooks.json"), "utf8"));
  for (const [event, blocks] of Object.entries(cfg.hooks)) {
    assert.ok(VALID.has(event), `unknown hook event: ${event}`);
    for (const block of blocks) {
      for (const h of block.hooks) {
        assert.match(h.command, /\$CLAUDE_PLUGIN_ROOT/, `${event}: hardcoded path in "${h.command}"`);
        const script = h.command.match(/\$CLAUDE_PLUGIN_ROOT\/([^"']+)/)?.[1];
        assert.ok(script && fs.existsSync(path.join(root, script)), `${event}: missing script ${script}`);
      }
    }
  }
});

test("every skill has SKILL.md with name and description", () => {
  const skillsDir = path.join(root, "skills");
  for (const e of fs.readdirSync(skillsDir, { withFileTypes: true })) {
    if (!e.isDirectory()) continue;
    const fm = frontmatter(path.join(skillsDir, e.name, "SKILL.md"));
    assert.match(fm, /^name:\s*\S/m, `skills/${e.name}: frontmatter missing name`);
    assert.match(fm, /^description:\s*\S/m, `skills/${e.name}: frontmatter missing description`);
  }
});

test("every command declares description and allowed-tools", () => {
  for (const f of walk(path.join(root, "commands"), ".md")) {
    const fm = frontmatter(f);
    assert.match(fm, /^description:\s*\S/m, `${path.relative(root, f)}: missing description`);
    assert.match(fm, /^allowed-tools:/m, `${path.relative(root, f)}: missing allowed-tools`);
  }
});

// Parsed from source, not imported — CI has no mcp/node_modules.
function forgeToolNames() {
  const src = fs.readFileSync(path.join(root, "mcp/tools.mjs"), "utf8");
  return [...src.matchAll(/^\s*name: "(\w+)"/gm)].map((m) => m[1]);
}

test("forge-db tool names are unique; commands/skills only reference real ones", () => {
  const names = forgeToolNames();
  assert.ok(names.length >= 7, `expected the forge-db tools, found ${names.length}`);
  assert.equal(new Set(names).size, names.length, "duplicate tool name in mcp/tools.mjs");
  for (const f of [...walk(path.join(root, "commands"), ".md"), ...walk(path.join(root, "skills"), ".md")]) {
    const src = fs.readFileSync(f, "utf8");
    for (const [, tool] of src.matchAll(/mcp__forge-db__(\w+)/g)) {
      assert.ok(names.includes(tool),
        `${path.relative(root, f)}: references unknown forge-db tool "${tool}"`);
    }
  }
});

test("SKILL.md repo-path references resolve to real files", () => {
  const skillsDir = path.join(root, "skills");
  for (const e of fs.readdirSync(skillsDir, { withFileTypes: true })) {
    if (!e.isDirectory()) continue;
    const skillDir = path.join(skillsDir, e.name);
    const src = fs.readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
    for (const [, ref] of src.matchAll(/`((?:references|scripts|commands|hooks|mcp|agents|tests)\/[\w./-]+\.\w+)`/g)) {
      assert.ok(
        fs.existsSync(path.join(skillDir, ref)) || fs.existsSync(path.join(root, ref)),
        `skills/${e.name}/SKILL.md: broken reference ${ref}`
      );
    }
  }
});

test(".mcp.json server entry points at an existing script", () => {
  const cfg = JSON.parse(fs.readFileSync(path.join(root, ".mcp.json"), "utf8"));
  for (const [name, srv] of Object.entries(cfg.mcpServers)) {
    for (const arg of srv.args ?? []) {
      if (!arg.includes("${CLAUDE_PLUGIN_ROOT}")) continue;
      const rel = arg.replace("${CLAUDE_PLUGIN_ROOT}/", "");
      assert.ok(fs.existsSync(path.join(root, rel)), `${name}: missing server script ${rel}`);
    }
  }
});

test("every agent declares name, description, tools", () => {
  for (const f of walk(path.join(root, "agents"), ".md")) {
    const fm = frontmatter(f);
    for (const key of ["name", "description", "tools"]) {
      assert.match(fm, new RegExp(`^${key}:`, "m"), `${path.relative(root, f)}: missing ${key}`);
    }
  }
});

test("shell scripts pass bash -n, .mjs files pass node --check", () => {
  for (const f of walk(root, ".sh")) {
    const r = spawnSync("bash", ["-n", f], { encoding: "utf8" });
    assert.equal(r.status, 0, `bash -n ${path.relative(root, f)}: ${r.stderr}`);
  }
  for (const f of walk(root, ".mjs")) {
    if (f.includes(`${path.sep}tests${path.sep}`)) continue;
    const r = spawnSync(process.execPath, ["--check", f], { encoding: "utf8" });
    assert.equal(r.status, 0, `node --check ${path.relative(root, f)}: ${r.stderr}`);
  }
});

test("session-start hook exits 0 and emits an LTX header", () => {
  const r = spawnSync("bash", [path.join(root, "hooks/scripts/session-start.sh")], {
    cwd: root,
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: root },
    encoding: "utf8",
  });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^@v1:/, `expected LTX header, got: ${r.stdout}`);
  for (const line of r.stdout.trim().split("\n").slice(1)) {
    assert.equal(line.split("|").length, 4, `malformed LTX row (want 4 fields): "${line}"`);
  }
});

test("record-change hook is a no-op (exit 0) without a database", () => {
  const env = { ...process.env };
  delete env.FORGE_DATABASE_URL;
  delete env.DATABASE_URL;
  for (const input of ['{"tool_name":"Write","tool_input":{"file_path":"/tmp/x"}}', "not json at all"]) {
    const r = spawnSync(process.execPath, [path.join(root, "mcp/record-change.mjs")], {
      input,
      env,
      encoding: "utf8",
    });
    assert.equal(r.status, 0, `hook must never block the tool (input: ${input}): ${r.stderr}`);
  }
});

test("statusline renders sample input", () => {
  const input = JSON.stringify({
    context_window: { used_percentage: 72 },
    workspace: { current_dir: root },
    model: { display_name: "Sonnet" },
  });
  const r = spawnSync("bash", [path.join(root, "scripts/statusline-command.sh")], {
    input,
    encoding: "utf8",
  });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /72%/, `expected context percentage in: ${r.stdout}`);
});

test("CLAUDE.md stays under its 12,000-character budget", () => {
  const size = fs.statSync(path.join(root, "CLAUDE.md")).size;
  assert.ok(size <= 12000, `CLAUDE.md is ${size} chars (budget 12000)`);
});
