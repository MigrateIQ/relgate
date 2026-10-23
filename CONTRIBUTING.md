# Contributing
 
## Layout
- `action.yml` + `scripts/` - the free tier (MIT).
- `pro/action.yml` + `pro/scripts/` - the Pro tier (FSL-1.1-MIT). Pro nests
  the free action pinned to `@v1`, so a free-tier change reaches Pro users
  only after the `v1` tag moves (see the release workflow).
- `test-fixtures/` and `.github/scripts/self-test/` - fixtures and the
  assertions the self-test workflow runs against them.
 
## Before you open a PR
Run the same checks CI runs:
 
```bash
pip install yamllint actionlint-py shellcheck-py
yamllint action.yml pro/action.yml
actionlint
shellcheck -S warning scripts/*.sh pro/scripts/*.sh .github/scripts/self-test/*.sh
bash .github/scripts/self-test/test-semver.sh
bash .github/scripts/self-test/test-annotate.sh
bash .github/scripts/self-test/test-sarif.sh   # needs jq
bash .github/scripts/self-test/test-baseline.sh   # needs jq
bash .github/scripts/self-test/test-cpm.sh        # needs perl
bash .github/scripts/self-test/test-config.sh     # needs yq, jq
bash .github/scripts/self-test/test-exclude.sh
bash .github/scripts/self-test/test-fail-gate.sh
python .github/scripts/self-test/check-github-script.py action.yml pro/action.yml  # needs node
```
 
Scripts assume Linux runners with bash 4+, `jq` and `curl` (all present on
`ubuntu-latest`). Keep logic in `scripts/` rather than inline in YAML so it
stays lintable and testable.
 
## Things to keep true
- Never print, log or persist a matched secret value.
- Auto-fixes must verify the build, skip fork PRs, and fail safe (push
  nothing) rather than push something wrong.
- A check that can't run (tool failure, outage) must say so, not report
  "clean".