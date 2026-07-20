# RelGate

Know your .NET release is ready before you tag it.

RelGate is a GitHub Action that checks .NET pull requests for unused usings, nullable warnings, and (in Pro) tests, build health, and vulnerable packages — posting one consolidated PR comment instead of scattered warnings.

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
    steps:
      - uses: actions/checkout@v4
      - uses: MigrateIQ/relgate@v1
```

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
| `changed-files-only` | `true` | Only check files changed in the PR |
| `fail-on-issues` | `true` | Fail the check on blocking issues |

## Roadmap

- Auto-fix mode (Pro)
- Full release gate: tests, build, vulnerability scan, changelog check (Pro)
- Debt trend dashboard
- AWS migration-readiness checks

## License

TBD
