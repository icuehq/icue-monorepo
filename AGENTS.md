# iCue agent instructions

## Instruction maintenance (required for every repository change)

Update instructions only when a change introduces or invalidates a critical,
durable rule: security boundaries, shared business contracts, architectural
constraints, or essential build/release workflows. Routine UI changes, local
implementation details, class names, pagination settings and task history belong
in code or focused documentation, not `AGENTS.md`. Most changes need no update.

When an update is necessary, edit or remove the existing rule rather than append
an overlapping one. Keep it brief and verify scope, contradictions, paths and
commands. Do not add changelog entries.

Root `AGENTS.md` is canonical; `CLAUDE.md` imports it. Add scoped files only for
substantial durable differences; give each scoped `AGENTS.md` a sibling `CLAUDE.md`
containing `@AGENTS.md`, because Claude Code reads only `CLAUDE.md` files once one
exists. Add `.agents/rules` only when conditional loading adds value beyond this
shared hierarchy; each rule file needs `trigger` frontmatter or Antigravity drops it.
Essential behavior must not depend on machine-local settings or fallback filenames.

## Code structure & screen size limits

- Screen files must not exceed 500 lines of code.
- Extract sub-views, forms, cards, and modal components into separate widget files in dedicated widget directories to maintain modularity, readability, and testability.

## Testing guidelines

- Do not write or add widget tests. Focus testing on pure unit, service, model, and business logic.

Final summaries must include either:

- `Instruction impact: reviewed; no instruction changes required.`
- `Instruction impact: updated <files> because <durable repository knowledge changed>.`
