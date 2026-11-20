# Releasing icue_sdk

`icue_sdk` and its shared dependency `packages/bus_tracking_core` are published
together to the private Cloudsmith registry
`https://dart.cloudsmith.io/icue/icue-sdk/`, by one command: `dart tool/release.dart` at
the repo root. There is no CI workflow; releases are run from a developer machine.

## Beta vs stable

| | Version | Who gets it |
|---|---|---|
| Beta | `X.Y.Z-beta.N` (`0.3.0-beta.1`) | Only consumers who pin that exact version. |
| Stable | `X.Y.Z` (`0.3.0`) | Anyone using `^0.3.0` or `any`. |

- Dart never picks a prerelease for a normal constraint such as `^0.2.0`, so
  nobody receives a beta by accident. They must write `version: 0.3.0-beta.1`.
- Betas say so at runtime: `IcueSdk.version`, `IcueSdk.isBeta`, and a log line
  on `IcueSdk.init` ("... is a BETA build ... not recommended for production").
- Every version is immutable. A fix is a new beta; never reuse a version.
- A stable is promoted from an accepted beta with no code changes.
- `bus_tracking_core` only has stable versions (`X.Y.Z`); it is a hidden
  dependency, so consumers never reference it directly.

## Release a beta

From the repo root, one command does everything:

```bash
dart tool/release.dart beta -m "What changed" -m "Another change" --dry-run   # preview
dart tool/release.dart beta -m "What changed" -m "Another change"             # publish
```

It picks the next version, edits the files, validates, asks `[y/N]`, then
publishes. `--dry-run` runs all the checks and prints every edit, then undoes
them and uploads nothing.

| Situation | Command |
|---|---|
| Next beta of the current version (`0.2.0-beta.2` -> `0.2.0-beta.3`) | `beta` |
| First beta of a new version (`0.2.0-beta.3` -> `0.3.0-beta.1`) | `beta --minor` (or `--patch`, `--major`) |
| Beta after a stable (`0.2.0` -> `0.2.1-beta.1`) | `beta --patch` (a level is required) |
| Also publish a new `bus_tracking_core` | add `--core patch` (or `minor`, `major`) |

Release notes come from the `-m` options, or from a `## Unreleased` section at
the top of `sdks/icue_sdk/CHANGELOG.md` if you give none (that section is
consumed). Notes are required.

What it edits for you:
- `sdks/icue_sdk/pubspec.yaml` and `lib/src/version.dart` (new version).
- `sdks/icue_sdk/CHANGELOG.md`: a new `## <version>` section with the notes.
- `sdks/icue_sdk/README.md`: version badge and the install snippet for the
  channel being released (beta pin, or stable `^X.Y.Z`).
- `icue-sdk-docs.html` and `icue-sdk-beta-docs.html`: only the version strings.
  A beta swaps the beta version (and `vX.Y` in titles when the minor changes) in
  both pages; a stable swaps the live version (dropdown, hero tag, install
  snippet, structured data) in both pages. Exact strings only.
- With `--core`: `packages/bus_tracking_core` version and CHANGELOG (same notes),
  and the SDK's `bus_tracking_core` constraint, which becomes `^<new version>`.

Then it runs `dart pub get`, analyze, tests and `dart pub publish --dry-run`,
publishes `bus_tracking_core` first (with `--core`), then `icue_sdk`. If a check
fails or you answer no, every edit is undone. If `bus_tracking_core` was
published but `icue_sdk` failed, the edits stay; fix the problem and rerun
without `--core`. Afterwards review `git diff` and commit.

Cloudsmith rejects a version that already exists, so a repeated version fails
at the publish step; use the next version.

`icue_sdk` depends on `bus_tracking_core`: when the SDK needs newer shared code,
release with `--core`, otherwise installing the SDK fails.

Not automated: the content of the HTML docs (new features, API changes,
examples) and `PROJECT_CONTEXT.md`. Update those by hand before releasing.

## Promote a beta to stable

```bash
dart tool/release.dart stable -m "Promoted from 0.3.0-beta.2" --dry-run
dart tool/release.dart stable -m "Promoted from 0.3.0-beta.2"
```

This turns the current beta (`0.3.0-beta.2`) into `0.3.0` with the same edits as
above. Do not add other code changes: a stable should be exactly the accepted
beta.

## Consumers

Stable (default, safe):

```yaml
icue_sdk:
  hosted:
    name: icue_sdk
    url: https://dart.cloudsmith.io/icue/icue-sdk/
  version: ^0.3.0
```

Beta (explicit opt-in, pin the exact build):

```yaml
icue_sdk:
  hosted:
    name: icue_sdk
    url: https://dart.cloudsmith.io/icue/icue-sdk/
  version: 0.3.0-beta.1
```

## One-time setup

- `dart pub token add https://dart.cloudsmith.io/icue/icue-sdk/` and paste a
  Cloudsmith write token. Never store it in this repository.
