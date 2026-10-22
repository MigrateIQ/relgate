# Security policy
 
## Reporting a vulnerability
 
Please report suspected vulnerabilities privately through GitHub's
**Security → Report a vulnerability** form on this repository, rather than a
public issue. Include the affected version (the tag or commit you reference
in your workflow) and steps to reproduce.
 
## What RelGate handles
 
- RelGate runs entirely on your own runner. It has no backend and sends no
  telemetry. The only network calls are the Pro license check (Lemon
  Squeezy) and, for Pro auto-remediation, advisory lookups against the
  GitHub advisory API.
- The Pro secret scan only ever records `file:line:pattern-type`. Matched
  values are never printed, logged or written to the report.
- Auto-fix features push commits to the PR branch using the job's
  `GITHUB_TOKEN`, and only when you grant `contents: write`. They skip fork
  PRs.
 
## Recommendations for users
 
- Pin RelGate (and the actions it uses) to a full commit SHA if your
  organization requires immutable references.
- Grant the job only the permissions it needs: `pull-requests: write` for
  the comment, plus `contents: write` only if you enable `auto-remediate`
  or `auto-fix-usings`.