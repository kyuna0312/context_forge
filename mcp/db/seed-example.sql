-- Example seed: one template so you can test /scaffold immediately.
-- Run:  psql "$FORGE_DATABASE_URL" -f mcp/db/seed-example.sql
--
-- File contents use dollar-quoted strings with real newlines. Do NOT use
-- '\n' in plain '...' literals: with standard_conforming_strings (the
-- default), Postgres stores the two characters backslash+n — the scaffolded
-- files would be one-line garbage and npm install would fail.

INSERT INTO templates (name, description, stack_json)
VALUES (
  'node-ts-basic',
  'Minimal Node + TypeScript starter',
  '{"runtime":"node","language":"typescript"}'
)
ON CONFLICT (name) DO NOTHING;

-- files
INSERT INTO template_files (template_id, path, content, ord)
SELECT t.id, v.path, v.content, v.ord
FROM templates t,
(VALUES
  ('package.json', $tpl${
  "name": "{{project_name}}",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "start": "node dist/index.js"
  }
}
$tpl$, 0),
  ('tsconfig.json', $tpl${
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
$tpl$, 1),
  ('src/index.ts', $tpl$export function main(): void {
  console.log("Hello from {{project_name}}");
}

main();
$tpl$, 2),
  ('.gitignore', $tpl$node_modules
dist
.env
$tpl$, 3)
) AS v(path, content, ord)
WHERE t.name = 'node-ts-basic'
ON CONFLICT (template_id, path) DO NOTHING;

-- deps (exact pinned versions — the forge contract; no ranges)
INSERT INTO template_deps (template_id, package, version, dev_dep)
SELECT t.id, v.package, v.version, v.dev_dep
FROM templates t,
(VALUES
  ('typescript', '5.6.3', true)
) AS v(package, version, dev_dep)
WHERE t.name = 'node-ts-basic'
ON CONFLICT (template_id, package) DO NOTHING;

-- Verify: SELECT path, left(content, 30) FROM template_files
--         JOIN templates ON templates.id = template_id
--         WHERE templates.name = 'node-ts-basic' ORDER BY ord;
