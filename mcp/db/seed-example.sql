-- Example seed: one template so you can test /scaffold immediately.
-- Run:  psql "$FORGE_DATABASE_URL" -f seed-example.sql

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
  ('package.json',
   '{\n  "name": "{{project_name}}",\n  "version": "0.1.0",\n  "type": "module",\n  "scripts": {\n    "build": "tsc",\n    "typecheck": "tsc --noEmit",\n    "start": "node dist/index.js"\n  }\n}\n', 0),
  ('tsconfig.json',
   '{\n  "compilerOptions": {\n    "target": "ES2022",\n    "module": "ESNext",\n    "moduleResolution": "bundler",\n    "outDir": "dist",\n    "strict": true,\n    "skipLibCheck": true\n  },\n  "include": ["src"]\n}\n', 1),
  ('src/index.ts',
   'export function main(): void {\n  console.log("Hello from {{project_name}}");\n}\n\nmain();\n', 2),
  ('.gitignore',
   'node_modules\ndist\n.env\n', 3)
) AS v(path, content, ord)
WHERE t.name = 'node-ts-basic'
ON CONFLICT (template_id, path) DO NOTHING;

-- deps
INSERT INTO template_deps (template_id, package, version, dev_dep)
SELECT t.id, v.package, v.version, v.dev_dep
FROM templates t,
(VALUES
  ('typescript', '^5.6.0', true)
) AS v(package, version, dev_dep)
WHERE t.name = 'node-ts-basic'
ON CONFLICT (template_id, package) DO NOTHING;
