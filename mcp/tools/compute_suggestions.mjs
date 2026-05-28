import { q } from "../db.mjs";

export const tool = {
  name: "compute_suggestions",
  description:
    "Analyse changelogs and produce/update template-improvement suggestions (the back-mapping feedback loop). E.g. if a dependency was manually added across many projects of the same template, suggest adding it to the template. Returns pending suggestions.",
  inputSchema: {
    type: "object",
    properties: { min_occurrences: { type: "number", default: 2 } },
  },
  handler: async ({ min_occurrences = 2 }) => {
    const rows = await q(
      `SELECT p.template_id, c.package, COUNT(DISTINCT c.project_id) AS seen
         FROM changelogs c
         JOIN projects p ON p.id = c.project_id
        WHERE c.change_type = 'dep_added'
          AND c.package IS NOT NULL
          AND p.template_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM template_deps td
             WHERE td.template_id = p.template_id AND td.package = c.package
          )
        GROUP BY p.template_id, c.package
       HAVING COUNT(DISTINCT c.project_id) >= $1`,
      [min_occurrences]
    );
    for (const r of rows) {
      await q(
        `INSERT INTO template_suggestions (template_id, kind, payload, occurrences)
         VALUES ($1,'add_dep',$2,$3)
         ON CONFLICT (template_id, kind, payload)
         DO UPDATE SET occurrences = EXCLUDED.occurrences, status='pending'`,
        [r.template_id, JSON.stringify({ package: r.package }), Number(r.seen)]
      );
    }
    return q("SELECT * FROM template_suggestions WHERE status='pending' ORDER BY occurrences DESC");
  },
};
