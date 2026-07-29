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
| License required | No | Yes ([Lemon Squeezy](https://lemonsqueezy.com)) |

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

## Inputs

| Input | Default | Description |
|---|---|---|
| `dotnet-version` | `8.0.x` | .NET SDK version |
| `project-path` | _(auto-detect)_ | Path to a `.sln` or `.csproj` to target |
| `changed-files-only` | `true` | Only check files changed in the PR |
| `fail-on-issues` | `true` | Fail the check on blocking issues |
| `pr-size-threshold` | `20` | Files-count above which the PR-size row is flagged (advisory only) |

## Pro tier

```yaml
      - uses: MigrateIQ/relgate/pro@v1
        with:
          license-key: ${{ secrets.RELGATE_LICENSE_KEY }}
```

Requires a [Lemon Squeezy](https://lemonsqueezy.com) license key, passed in
via a repo secret. Everything Pro computes runs locally on your own runner —
there's no dashboard, no telemetry, and no persisted history. The license
check itself fails open: if Lemon Squeezy is unreachable, your pipeline
isn't blocked, Pro checks just don't run for that job.

| Category | Severity | Behavior |
|---|---|---|
| Vulnerability readiness score | Blocking | Severity-weighted score from `dotnet list package --vulnerable`, gated against `vuln-readiness-threshold` |
| Secret-leakage scan | Blocking | Regex-based scan for leaked credentials in changed files. Matched values are never printed — only the file, line, and pattern type |
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

- Only top-level `PackageReference` vulnerabilities in standard projects
  are fixed. Purely transitive vulnerabilities and repos using [Central
  Package Management](https://learn.microsoft.com/nuget/consume-packages/central-package-management)
  are reported but not auto-fixed.
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

## Roadmap

- Cross-repo/org debt-trend rollup and alerting

## License

RelGate core (this repo, excluding `pro/`) is licensed under the [MIT License](LICENSE).

RelGate Pro (`pro/`) is licensed under the [Functional Source License, Version 1.1, MIT Future License](pro/LICENSE.md) (FSL-1.1-MIT). You're free to use, read, modify, and redistribute it for any Permitted Purpose — including running it on your own repos and runners — but not to repackage it into a competing product or service. Each version converts to plain MIT two years after its release. See [`pro/LICENSE.md`](pro/LICENSE.md) for the full terms, and [`pro/LICENSING-FAQ.md`](pro/LICENSING-FAQ.md) for a plain-English explainer.
