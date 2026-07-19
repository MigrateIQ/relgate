# RelGate — Build Plan

**Repo:** `migrateiq/relgate`
**Tagline:** Run RelGate before you tag a release.
**What it is:** A GitHub Action (composite action) that gates PRs/releases on code hygiene, tests, build, and vulnerabilities. Not a bot, not a package — GitHub hosts execution, we only host license validation.

---

## Phase 0: Setup (1 day)
- [ ] Create repo `migrateiq/relgate` in the MigrateIQ org
- [ ] Confirm `relgate` isn't already taken elsewhere (GitHub, npm, socials) before locking it in everywhere
- [ ] Add `.editorconfig` with StyleCop + Roslynator + nullable/async rule severities set to warning
- [ ] Write README stub with tagline and free vs pro framing

## Phase 1: Free MVP — reporting only, no license gate (1–2 weekends)
- [ ] Composite `action.yml`: `dotnet restore` + `dotnet format analyzers --verify-no-changes` across:
  - Unused usings (IDE0005)
    - Naming conventions (StyleCop)
      - Nullable reference warnings
        - Async/await misuse (Meziantou/VSTHRD)
        - [ ] Diff-aware: only flag issues in files changed in the PR (use `tj-actions/changed-files`)
        - [ ] Consolidated single PR comment with severity tiers (blocking vs advisory) — this is the core differentiator, worth polishing even in free tier
        - [ ] No license key, no auto-fix, no gating logic yet
        - [ ] Consumer usage: `uses: migrateiq/relgate@v1`
        - [ ] Ship: publish repo + `v1` tag, launch post via blog → dev.to → X → LinkedIn → newsletter loop

        **Exit criteria to move to Phase 2:** real usage (stars, installs, or direct asks) — not a calendar date.

        ## Phase 2: Validate demand (ongoing, no code)
        - [ ] Watch for unprompted requests: auto-fix, multi-repo, full release gate
        - [ ] Ask cohort directly: would they pay for the paid tier?
        - [ ] Only proceed to Phase 3 if there's real signal

        ## Phase 3: Paid tier — RelGate Pro (2–3 weekends, only if Phase 2 validates)
        - [ ] Cloudflare Worker + KV for license validation (`/validate` endpoint: key, repo → valid/tier)
          - KV record: `{ customer, expires, revoked }`
            - Revoke on refund: `wrangler kv key put ... '{"revoked":true}'`
            - [ ] Extend `action.yml`: `mode: fix` gated by `license-key` input
              - Auto-fix safe rules only (usings, naming, formatting) — never auto-fix nullable/async (behavior risk)
                - Opens PR via `peter-evans/create-pull-request`, branch `bot/relgate-fixes`
                - [ ] Full release gate bundle:
                  - Tests passing (`dotnet test`)
                    - Build succeeds (warnings-as-errors on critical categories)
                      - Vulnerability scan (`dotnet list package --vulnerable --include-transitive`)
                        - Changelog check (fail if source changed but `CHANGELOG.md`/version not bumped)
                        - [ ] Gumroad listing: separate SKU, license key auto-delivery (or manual `wrangler kv key put` sync for v1)
                        - [ ] README/landing copy updated with free vs pro comparison table

                        ## Phase 4: Differentiation (only once Phase 3 has paying customers)
                        - [ ] Debt trend dashboard over time (needs storage + simple web UI)
                        - [ ] Migration-readiness score
                        - [ ] AWS Transform-aware checks — Windows-only API usage, legacy config patterns (the actual moat, ties back to MigrateIQ's migration niche)
                        - [ ] Slack/email digests, leaderboards, PDF/CSV export — build only if requested

                        ---

                        ## Guardrail
                        Don't start a phase until the previous one's exit criteria is met by **real usage**, not assumption. Technical build is low-risk throughout; the open question is always demand, not feasibility.

                        ## Architecture summary
                        | Piece | Where it lives |
                        |---|---|
                        | Action code (`action.yml`, checks) | `migrateiq/relgate` — public repo, GitHub hosts execution |
                        | License validation (Phase 3+) | Cloudflare Worker + KV |
                        | Sales (Phase 3+) | Gumroad — standalone SKU, separate from cohort |
                        | Docs/marketing | Existing MigrateIQ channels + content loop |
                        