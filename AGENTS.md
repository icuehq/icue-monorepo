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

## Repository layout

Flutter/Dart Pub workspace (root `pubspec.yaml`) managed with Melos. Every package
must be listed under `workspace:` and use `resolution: workspace`.

- `apps/icueadmin` — the production admin app (go_router, provider, get_it). Screens live in `lib/features/<name>/`, routing in `lib/routing/`, DI bootstrap in `lib/di/`.
- `apps/impl` — scaffold only; do not build features here.
- `features/<name>` — one package per business domain (auth, drivers, vehicles, routes, announcements, expenses, logbook, reports, gatepass, tracking, drop_boarding, attendance). Each has `models/`, `services/`, `providers/`, `di/` under `lib/src/` and exports its public API from `lib/<name>.dart`.
- `packages/api_client` — HTTP client, interceptors, errors, `ApiEnvironment`. `packages/local_storage`, `packages/core_ui` (shared widgets/utils), `packages/icue_firebase`, `packages/icue_face_sdk` (native Android/iOS plugin).

## Architecture rules

- Dependencies point downward: apps → features → packages. Feature packages must never depend on an app. Feature-to-feature dependencies are limited to the existing `auth` and `routes` base features (no cycles); other shared code moves to `packages/`.
- Apps import a feature only through its barrel file, never `package:<feature>/src/...`.
- Feature UI (pages/widgets) lives in the app; feature packages hold models, services and providers only.
- Dependency injection uses `get_it` + `injectable`. Each feature package declares a micro-package module; the app aggregates them in `lib/di/injection.dart`. A new feature package must be registered in the app's `injection.dart` and the root `workspace:` list.
- All HTTP goes through `api_client`; do not create ad-hoc `Dio`/`http` clients in features or apps.
- API base URL is selected at build time via `--dart-define=ENV=` (or `FLAVOR=`). Never hardcode environment URLs elsewhere.

## Security boundaries

- Never commit secrets: signing keystores, `.p8`/`.pepk` keys, `passwords.txt`, `.env` files, API tokens. Never read, print, copy or reference their contents in output.
- `AuthKey_*.p8`, `keystore.jks`, `private_key.pepk`, `passwords.txt` at the repo root are currently tracked by git and must be removed from history/rotated by the owner; do not add similar files, and add new secret patterns to `.gitignore` first.
- Do not log tokens, OTPs, phone numbers or face/biometric data.

## Commands

Run from the repo root (`dart pub get` first; `melos bootstrap` is not needed with workspaces):

- `melos run lint` — `flutter analyze` on every package (must pass with no errors/warnings).
- `melos run format` / `melos run format:check` — Dart formatting.
- `melos run test` — tests in every package with a `test/` dir.
- `melos run gen` — `build_runner` (injectable DI config). Re-run after changing any `@injectable`/annotated class or adding a package module.

Never hand-edit `*.g.dart`, `*.module.dart`, `injection.config.dart` or other generated files.

## Code style

- Lints are defined in the root `analysis_options.yaml` (strict casts/inference/raw types, single quotes, trailing commas, `always_use_package_imports`, `prefer_final_locals`). Follow them; do not add `// ignore:` without a documented reason (`document_ignores` is on).
- Use package imports, never relative `../` imports.

## Code structure & screen size limits

- Screen files must not exceed 500 lines of code.
- Extract sub-views, forms, cards, and modal components into separate widget files in dedicated widget directories to maintain modularity, readability, and testability.

## Testing guidelines

- Do not write or add widget tests. Focus testing on pure unit, service, model, and business logic.
- Tests live in the owning package's `test/` directory.

## Git

- Branch from `main`; use conventional commits with scope (`feat(auth): ...`, `fix(core_ui): ...`).
- Don't commit `build/`, `.dart_tool/`, `.idea/` or generated platform secrets.

Final summaries must include either:

- `Instruction impact: reviewed; no instruction changes required.`
- `Instruction impact: updated <files> because <durable repository knowledge changed>.`
