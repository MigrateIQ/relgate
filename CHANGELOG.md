# Changelog
 
## Unreleased
 
### Fixed
- Fork PRs (and any token without `pull-requests: write`) no longer fail the
  check when the PR comment can't be posted; the report is written to the
  job summary instead.
- The PR comment is found across all pages of comments, so busy PRs no
  longer accumulate duplicate RelGate comments.
- The comment step now runs even if an earlier step failed, so a crash still
  produces a report.
- Changed-file lists are handled newline-separated, so file names containing
  spaces no longer break the usings, nullable, PR-size, secret and auto-fix
  steps.
- Pro: auto-remediate and auto-fix-usings now commit on top of the real PR
  head. On `pull_request` events the checkout is the merge commit, and
  pushing from it could have pulled base-branch changes into the PR. If the
  fix no longer applies cleanly, nothing is pushed.
- Pro: the vulnerability score counts each distinct (package, version,
  advisory) once instead of once per target framework / project.
- Pro: version comparison handles prerelease versions correctly (previously
  `1.0.0-beta` could outrank `1.0.0`).
- Pro: the report artifact is only uploaded when licensed, and its name is
  configurable (`report-artifact-name`) so multiple invocations don't clash.
 
### Added
- Inline PR annotations for unused usings, nullable warnings and (Pro)
  secret-scan hits.
- Pro secret scan: JSON-style `"password": "..."` assignments, AWS access
  key IDs and GitHub tokens; `relgate:ignore` line marker; the
  `secret-scan-exclude` input; file:line:type listed in the PR comment.
- Pro: opt-in `upload-sarif` publishes findings (usings, nullable, secrets,
  vulnerable packages) to GitHub code scanning; exposes `sarif-path`.
- Pro: opt-in baseline (ratchet) mode via `baseline-file` / `baseline-write`:
  accept today's unused usings and secret hits and fail only on new ones.
  Stores per-file counts only - no line numbers, source text or hashes.
- Pro: auto-remediate supports Central Package Management by editing
  `Directory.Packages.props` (previously those repos were skipped).
- Optional `.relgate.yml` (`config-file` input): per-check severity
  (`blocking` / `advisory` / `off`) for unused usings, nullable warnings and
  (Pro) secrets and vulnerabilities, plus path `exclude` globs. Invalid files
  fail the job rather than silently using defaults. Note: Pro nests the free
  action at `@v1`, so config support reaches Pro's usings/nullable counts
  once `v1` is moved to the release containing it.
- CI: shellcheck, actionlint, yamllint on both actions, unit tests for
  version comparison and annotations, a pull-request integration workflow,
  Dependabot for GitHub Actions, and a tag-driven release workflow.