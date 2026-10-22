# RelGate
 
Know your .NET release is ready before you tag it.
 
RelGate is a GitHub Action that checks .NET pull requests for unused usings
and nullable warnings, and — in Pro — a vulnerability readiness score and a
secret-leakage scan, posting one consolidated PR comment instead of
scattered warnings.
 
## Free vs. Pro
 
| | Free | Pro |
|---|---|---|
| Unused usings check | ✅ Blocking | ✅ Blocking |
| Nullable warnings | ✅ Advisory | ✅ Advisory |
| Build health check | ✅ Blocking | ✅ Blocking |
| PR size nudge | ✅ Advisory | ✅ Advisory |
| Consolidated PR comment | ✅ | ✅ (extended with Pro results) |
| Vulnerability readiness score | – | ✅ Blocking |
| Secret-leakage scan | – | ✅ Blocking |
| Auto-remediation for vulnerable packages | - | ✅ Opt-in |
| Auto-fix unused usings | - | ✅ Opt-in |
| On-the-fly HTML report | – | ✅ |
| Runs entirely on your own runner | ✅ | ✅ (no dashboard, no telemetry) |
| License required | No | Yes ([Lemon Squeezy](Payments, Tax & Subscriptions for SaaS)) |
 
## Usage
 
```yaml
name: RelGate Check
 
on:
  pull_request:
 
jobs:
  relgate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write # required to post the PR comment
    steps:
      - uses: actions/checkout@v4
      - uses: MigrateIQ/relgate@v1
```
 
RelGate posts its report as a PR comment, which needs
`pull-requests: write` on the job's `GITHUB_TOKEN`. Many orgs default
`GITHUB_TOKEN` to read-only, so this permission must be granted explicitly
as shown above — without it, the comment step will fail with a 403.
 
## What it checks (free tier)
 
| Category | Severity | Behavior |
|---|---|---|
| Unused usings (IDE0005) | Blocking | Fails the check |
| Nullable warnings | Advisory | Reported, doesn't fail |
| PR size | Advisory | Flags PRs touching more than `pr-size-threshold` files, never fails |
 
Only files changed in the PR are checked by default (`changed-files-only: true`).
 
Unused usings and nullable warnings are also annotated inline on the PR diff
(up to 10 per check, so a noisy PR doesn't flood the Files tab); the PR
comment always carries the full count. Pro adds the same for secret-scan hits.
 
## Inputs
 
| Input | Default | Description |
|---|---|---|
| `dotnet-version` | `8.0.x` | .NET SDK version |
| `project-path` | _(auto-detect)_ | Path to a `.sln` or `.csproj` to target |
| `changed-files-only` | `true` | Only check files changed in the PR |
| `fail-on-issues` | `true` | Fail the check on blocking issues |
| `pr-size-threshold` | `20` | Files-count above which the PR-size row is flagged (advisory only) |
| `config-file` | `.relgate.yml` | Optional config file: per-check severity and path excludes ([details](#configuration-file)) |
 
## Configuration file
 
Drop a `.relgate.yml` in the repo root to set how strictly each check is
enforced and which paths to ignore. It applies to both tiers; the Pro keys
(`secrets`, `vulnerabilities`) are ignored by the free action.
 
```yaml
version: 1
 
checks:
  unused-usings: blocking     # blocking | advisory | off   (default: blocking)
  nullable-warnings: advisory # blocking | advisory | off   (default: advisory)
  secrets: blocking           # Pro                         (default: blocking)
  vulnerabilities: blocking   # Pro                         (default: blocking)
 
exclude:                      # findings in matching files are ignored
  - "**/Migrations/**"
  - "**/*.Designer.cs"
  - "src/Generated/"
```
 
- **`blocking`** findings fail the check. **`advisory`** findings are still
  reported (comment, annotations) but never fail it. **`off`** skips the
  check and drops its row from the report.
- A build that doesn't compile always blocks; it isn't configurable.
- **`exclude`** globs are matched against repo-relative paths; `*` matches
  across directories, so `*.g.cs` works at any depth, and a trailing `/`
  means "this directory and everything under it". Excluded files don't
  count toward usings, nullable warnings or secret hits, and get no
  annotations. (Use `secret-scan-exclude` or `relgate:ignore` for
  secret-scan-only suppressions.)
- The file only holds what has no workflow input. Runtime settings such as
  `dotnet-version`, `project-path` and the thresholds stay workflow inputs,
  so nothing is ever set in two places.
- An **invalid** file (bad YAML, an unknown severity, a wrong type) fails the
  job with a clear error instead of falling back to defaults — a typo must
  not quietly weaken the gate. Unknown keys only warn. Reading it needs
  `yq`, which GitHub-hosted runners include.
 
**Protect this file.** On pull requests the config is read from the PR's own
branch, so a PR can change it — the same is true of a baseline file. Both
show up in the diff, but if you rely on them as policy, require review for
them with a [`CODEOWNERS`](About code owners - GitHub Docs)
entry:
 
```
/.relgate.yml            @your-org/maintainers
/.relgate/baseline.json  @your-org/maintainers
```
 
## Pro tier
 
```yaml
      - uses: MigrateIQ/relgate/pro@v1
        with:
          license-key: ${{ secrets.RELGATE_LICENSE_KEY }}
```
 
Requires a [Lemon Squeezy](Payments, Tax & Subscriptions for SaaS) license key, passed in
via a repo secret. Everything Pro computes runs locally on your own runner —
there's no dashboard, no telemetry, and no persisted history. The license
check itself fails open: if Lemon Squeezy is unreachable, your pipeline
isn't blocked, Pro checks just don't run for that job.
 
| Category | Severity | Behavior |
|---|---|---|
| Vulnerability readiness score | Blocking | Severity-weighted score from `dotnet list package --vulnerable`, gated against `vuln-readiness-threshold`. Each distinct (package, version, advisory) counts once, however many target frameworks or projects it appears in |
| Secret-leakage scan | Blocking | Regex-based scan for leaked credentials in changed files: `key=value`, YAML and JSON (`"password": "…"`) assignments, private-key headers, AWS access key IDs and GitHub tokens. Matched values are never printed — only the file, line, and pattern type, which are listed in the PR comment. Add `relgate:ignore` to a line to suppress a known-safe match |
| Auto-remediation | Opt-in, never blocking | Bumps vulnerable to-level packages to their minimum patched version and pushes a fix
commit to the PR branch |
 
`vuln-readiness-threshold` and `vuln-benchmark` are plain, visible,
user-editable inputs (defaults `80` and `75`) — not derived from any
external dataset. Treat `vuln-benchmark` as a reference point you set
yourself, not a live comparison against other users.
 
### Pro inputs
 
In addition to all the free-tier inputs above:
 
| Input | Default | Description |
|---|---|---|
| `license-key` | _(required)_ | Lemon Squeezy license key |
| `vuln-readiness-threshold` | `80` | Minimum score (0-100) required to pass |
| `vuln-benchmark` | `75` | Reference score shown alongside your own |
| `license-api-url` | Lemon Squeezy's API | Override only for testing |
| `auto-remediate` | `false` | Opt-in: push a fix commit for vulnerable packages with a known patch |
| `auto-fix-usings` | `false` | Opt-in: push a fix commit that removes unused usings |
| `baseline-file` | _(none)_ | Opt-in ratchet mode: path of a baseline file; only findings beyond it fail the check |
| `baseline-write` | `false` | Record today's findings to `baseline-file` instead of gating |
| `upload-sarif` | `false` | Opt-in: upload findings to GitHub code scanning as SARIF (needs `security-events: write`) |
| `secret-scan-exclude` | _(none)_ | Space- or comma-separated globs the secret scan skips, e.g. `docs/*,*.md` |
| `report-artifact-name` | `relgate-report` | Name of the uploaded HTML report; set a unique value if Pro runs more than once per workflow run |
 
### Auto-remediation
 
Enabling `auto-remediate: true` lets Pro push a commit to the PR branch
that bumps vulnerable top-level packages to their minimum known-patched
version, instead of only reporting them:
 
```yaml
jobs:
  relgate:
    runs-on: ubuntu-latest
    permissions:
      contents: write # required in addition to pull-requests: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: MigrateIQ/relgate/pro@v1
        with:
          license-key: ${{ secrets.RELGATE_LICENSE_KEY }}
          auto-remediate: "true"
```
 
`contents: write` must be granted on the calling job — composite actions
can't elevate their own permissions.
 
**Scope and known limitations, by design:**
 
- Only top-level package vulnerabilities are fixed. Purely transitive
  vulnerabilities are reported but not auto-fixed.
- [Central Package Management](Central Package Management | Microsoft Learn)
  is supported: the `PackageVersion` entry in `Directory.Packages.props`
  is updated (not the project file). Only entries pinned at the exact
  vulnerable version are rewritten, so a per-framework conditional entry on
  a different version is never moved. Version ranges, floating versions and
  a project-level `VersionOverride` are left alone and the package is
  reported as not fixed.
- Packages are bumped to the *minimum* patched version, not the latest,
  to avoid pulling in unrelated breaking changes.
- After bumping, RelGate rebuilds the project. If the build breaks, the
  fix is discarded — no commit is made. A clean build isn't the same as
  a correct one: no tests are run as part of this.
- Fork PRs are skipped — a fork's `GITHUB_TOKEN` can't push to the base
  repo.
- The vulnerability readiness score always reflects the pre-remediation
  state, so the report shows what was found, not a silently-cleaned
  number.
- A push made with the default `GITHUB_TOKEN` does **not** re-trigger the
  `pull_request` check, so the PR's status won't auto-refresh after a fix
  is pushed. Re-running the existing check replays the *same* commit it
  originally ran against — it won't pick up the fix. Push a new commit or
  reopen the PR to get a fresh check against the fixed code.
 
### Auto-fix usings
 
Enabling `auto-fix-usings: true` lets Pro push a commit to the PR branch
that removes unused usings (the same fix `dotnet format style
--diagnostics IDE0005` would apply locally), instead of only reporting
them:
 
```yaml
jobs:
  relgate:
    runs-on: ubuntu-latest
    permissions:
      contents: write # required in addition to pull-requests: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: MigrateIQ/relgate/pro@v1
        with:
          license-key: ${{ secrets.RELGATE_LICENSE_KEY }}
          auto-fix-usings: "true"
 ```
 
Uses the same `contents: write` permission as `auto-remediate` — enabling
both costs no extra setup.
 
**Scope and known limitations, by design:**
 
- Only fixes usings within the same changed-files scope the free-tier
  check already used — it won't clean up unrelated repo-wide debt.
- After removing usings, RelGate rebuilds the project. If the build
  breaks (rare — e.g. a using needed only for a conditional-compilation
  branch), the fix is discarded — no commit is made.
- Fork PRs are skipped — a fork's `GITHUB_TOKEN` can't push to the base
  repo.
- The "Unused usings" row keeps reflecting the pre-fix state honestly;
  the "Auto-fix usings" row reports what was actually done about it.
- Same push-doesn't-auto-refresh limitation as auto-remediation above —
  push a new commit or reopen the PR to see it reflected.
 
## Requirements
 
RelGate's scripts are bash and expect a Linux runner (`ubuntu-latest`) with
bash 4+, `jq` and `curl`. macOS and Windows runners aren't supported.
 
## Troubleshooting
 
- **The check passes but there's no PR comment.** On fork PRs, and wherever
  `GITHUB_TOKEN` is read-only, RelGate can't post comments. It doesn't fail
  the check; the report is written to the job's summary page instead. Grant
  `pull-requests: write` (see [Usage](#usage)) to get the comment on
  same-repo PRs.
- **Auto-fix or auto-remediation didn't push.** It needs `contents: write`
  on the job, skips fork PRs, discards the fix if the build would break, and
  pushes nothing if the base branch changed the same lines. The "Auto-fix"
  and "Auto-remediation" rows in the report say which of these happened.
- **A secret-scan finding is a false positive.** Add `relgate:ignore` to
  that line, or exclude paths with `secret-scan-exclude`.
- **Running Pro more than once in a workflow run fails on the report
  upload.** Give each invocation a distinct `report-artifact-name`.
 
### Baseline (ratchet) mode
 
Adopting RelGate on a legacy codebase shouldn't mean fixing every old finding
first. With a baseline, today's unused usings and secret hits are accepted
and only **new** ones fail the check.
 
1. Record the baseline once, on the whole repo (a manually triggered run on
   your default branch works well):
 
   ```yaml
   - uses: MigrateIQ/relgate/pro@v1
     with:
       license-key: ${{ secrets.RELGATE_LICENSE_KEY }}
       changed-files-only: "false"
       baseline-file: .relgate/baseline.json
       baseline-write: "true"
   ```
 
   Download the `relgate-baseline` artifact from that run and commit it as
   `.relgate/baseline.json`.
 
2. On pull requests, point at the committed file:
 
   ```yaml
   - uses: MigrateIQ/relgate/pro@v1
     with:
       license-key: ${{ secrets.RELGATE_LICENSE_KEY }}
       baseline-file: .relgate/baseline.json
   ```
 
The PR comment then shows e.g. `0 (+12 baselined)`: baselined findings are
reported but never block.
 
**How it works, by design:**
 
- The baseline stores **counts only** — unused usings per file, and secret
  hits per file and type. No line numbers (they shift with every edit) and
  no source text or hashes (nothing derived from a secret is ever written to
  your repo). A finding is new when a file's current count exceeds its
  baselined count.
- Known limitation: fixing one finding and adding another in the same file
  nets to zero, and isn't flagged.
- Only unused usings and secrets are baselined. Vulnerable packages keep
  their own `vuln-readiness-threshold`; build failures always block.
- A missing or invalid baseline file is treated as an empty one (everything
  is new) with a warning, so a typo in the path can't silently disable the
  gate.
- Re-run `baseline-write` whenever you want to ratchet down after cleaning
  up — a smaller baseline means fewer accepted findings.
 
### Code scanning (SARIF)
 
Set `upload-sarif: "true"` to send RelGate's findings to the repository's
**Security → Code scanning** tab, alongside the PR comment and inline
annotations:
 
```yaml
jobs:
  relgate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      security-events: write # required for upload-sarif
    steps:
      - uses: actions/checkout@v4
      - uses: MigrateIQ/relgate/pro@v1
        with:
          license-key: ${{ secrets.RELGATE_LICENSE_KEY }}
          upload-sarif: "true"
```
 
| Rule | Finding | Level |
|---|---|---|
| `RG001` | Unused using directive | error |
| `RG002` | Nullable reference warning | warning |
| `RG003` | Potential secret (file/line/type only — never the value) | error |
| `RG004` | Vulnerable package (pinned to line 1 of the project file) | by severity |
 
Code scanning must be available for the repository (public repos, or private
repos with GitHub Code Security). If the upload is rejected — fork PRs, a
missing permission, code scanning disabled — the step is skipped quietly and
never fails the check. The generated file path is also exposed as the
`sarif-path` output.
 
## Roadmap
 
- Cross-repo/org debt-trend rollup and alerting
 
## License
 
RelGate core (this repo, excluding `pro/`) is licensed under the [MIT License](LICENSE).
 
RelGate Pro (`pro/`) is licensed under the [Functional Source License, Version 1.1, MIT Future License](pro/LICENSE.md) (FSL-1.1-MIT). You're free to use, read, modify, and redistribute it for any Permitted Purpose — including running it on your own repos and runners — but not to repackage it into a competing product or service. Each version converts to plain MIT two years after its release. See [`pro/LICENSE.md`](pro/LICENSE.md) for the full terms, and [`pro/LICENSING-FAQ.md`](pro/LICENSING-FAQ.md) for a plain-English explainer.