-- project-forge schema (Postgres)
-- Run once against your remote DB:  psql "$FORGE_DATABASE_URL" -f schema.sql

CREATE TABLE IF NOT EXISTS templates (
  id           SERIAL PRIMARY KEY,
  name         TEXT UNIQUE NOT NULL,        -- e.g. "nextjs-trpc-drizzle"
  description  TEXT,
  stack_json   JSONB NOT NULL DEFAULT '{}', -- { "framework": "next", "orm": "drizzle", ... }
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Files belonging to a template. content is a literal template string with
-- {{placeholders}} that the scaffolder substitutes. The MODEL DOES NOT WRITE
-- THIS CONTENT — it is read verbatim from the DB.
CREATE TABLE IF NOT EXISTS template_files (
  id           SERIAL PRIMARY KEY,
  template_id  INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
  path         TEXT NOT NULL,               -- relative path inside the new project
  content      TEXT NOT NULL DEFAULT '',
  is_binary    BOOLEAN NOT NULL DEFAULT false,
  ord          INTEGER NOT NULL DEFAULT 0,
  UNIQUE (template_id, path)
);

CREATE TABLE IF NOT EXISTS template_deps (
  id           SERIAL PRIMARY KEY,
  template_id  INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
  package      TEXT NOT NULL,
  version      TEXT NOT NULL DEFAULT 'latest',
  dev_dep      BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (template_id, package)
);

CREATE TABLE IF NOT EXISTS projects (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  template_id  INTEGER REFERENCES templates(id) ON DELETE SET NULL,
  root_path    TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Every change observed in a project. Written automatically by the PostToolUse hook.
CREATE TABLE IF NOT EXISTS changelogs (
  id           SERIAL PRIMARY KEY,
  project_id   INTEGER REFERENCES projects(id) ON DELETE CASCADE,
  project_name TEXT,                         -- denormalised fallback when project unknown
  change_type  TEXT NOT NULL,                -- file_created | file_edited | dep_added | stack_changed
  file_path    TEXT,
  package      TEXT,                         -- set for dep_added
  version      TEXT,
  stack_delta  JSONB,                        -- diff vs the template's stack, if any
  summary      TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Back-mapping: suggestions to improve a template, derived from changelogs.
CREATE TABLE IF NOT EXISTS template_suggestions (
  id                 SERIAL PRIMARY KEY,
  template_id        INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
  kind               TEXT NOT NULL,          -- add_dep | add_file | change_stack
  payload            JSONB NOT NULL,         -- e.g. { "package": "zod", "seen_in": 4 }
  occurrences        INTEGER NOT NULL DEFAULT 1,
  status             TEXT NOT NULL DEFAULT 'pending', -- pending | applied | dismissed
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (template_id, kind, payload)
);

CREATE INDEX IF NOT EXISTS idx_changelogs_project ON changelogs(project_id);
CREATE INDEX IF NOT EXISTS idx_changelogs_type    ON changelogs(change_type);
CREATE INDEX IF NOT EXISTS idx_tfiles_template    ON template_files(template_id);
CREATE INDEX IF NOT EXISTS idx_tdeps_template     ON template_deps(template_id);
