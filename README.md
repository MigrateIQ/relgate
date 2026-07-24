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
| Consolidated PR comment | ✅ | ✅ (extended with Pro results) |
| Vulnerability readiness score | – | ✅ Blocking |
| Secret-leakage scan | – | ✅ Blocking |
| On-the-fly HTML report | – | ✅ |
| Runs entirely on your own runner | ✅ | ✅ (no dashboard, no telemetry) |
| License required | No | Yes ([Lemon Squeezy](https://lemonsqueezy.com)) |

## Usage

```yaml
name: RelGate Check

on:
  pull_request:
    paths:
      - '**/*.cs'

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

Only files changed in the PR are checked by default (`changed-files-only: true`).

## Inputs

| Input | Default | Description |
|---|---|---|
| `dotnet-version` | `8.0.x` | .NET SDK version |
| `project-path` | _(auto-detect)_ | Path to a `.sln` or `.csproj` to target |
| `changed-files-only` | `true` | Only check files changed in the PR |
| `fail-on-issues` | `true` | Fail the check on blocking issues |

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

## Roadmap

- Auto-fix mode
- Cross-repo/org debt-trend rollup and alerting

## License

RelGate core (this repo, excluding `pro/`) is licensed under the [MIT License](LICENSE).

RelGate Pro (`pro/`) is licensed under the [Functional Source License, Version 1.1, MIT Future License](pro/LICENSE.md) (FSL-1.1-MIT). You're free to use, read, modify, and redistribute it for any Permitted Purpose — including running it on your own repos and runners — but not to repackage it into a competing product or service. Each version converts to plain MIT two years after its release. See [`pro/LICENSE.md`](pro/LICENSE.md) for the full terms, and [`pro/LICENSING-FAQ.md`](pro/LICENSING-FAQ.md) for a plain-English explainer.
