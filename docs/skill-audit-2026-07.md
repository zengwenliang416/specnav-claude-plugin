# Skill Layer Audit (2026-07, P3.2)

Checklist applied to all 45 SKILL.md files across the 7 plugins
(auto-verified by `tests/run-skill-contract-fixtures.sh`; numbers from the
audit run on 2026-07-03).

| Check | Result |
| --- | --- |
| Body ≤ 500 lines (progressive disclosure) | PASS — max is 53 lines (`specnav-route`); reference material already lives in `references/` |
| `description` ≤ 1536 chars | PASS — all well under |
| Description starts with trigger language ("Use this skill when…") | PASS — all 45 |
| Frontmatter strict subset | PASS — allowed keys: `name`, `description`, `context`, `agent`, `disable-model-invocation` (contract-enforced) |
| Dangerous skills user-only | FIXED — `specnav-deploy` and `specnav-rollback` now carry `disable-model-invocation: true`; `specnav-release-plan` writes plans only (no outward action) and stays model-invocable |
| Isolated review context | `specnav-task-review` uses `context: fork` + `agent: verifier` (P2.2) |

## Deliberately not adopted

- **`allowed-tools` frontmatter** — the suite's contract test explicitly bans
  it (`run-skill-contract-fixtures.sh` rejects `allowed-tools:`) because tool
  permission grants belong in project/user settings, not in skill files that
  install from a marketplace. Reducing permission prompts is a consumer-side
  settings concern.
- **`paths` frontmatter** — SpecNav skills are lifecycle-scoped, not
  file-scoped; auto-loading by path pattern would fire skills outside their
  stage.

## Eval baseline (deferred, tracked here)

The plan called for skill-creator eval baselines on `specnav-requirements`,
`specnav-fix`, and `specnav-break-loop`. This requires interactive Claude
sessions and eval-case authoring beyond deterministic CI; it is deferred to a
follow-up change. What exists today as a proxy:

- `run-skill-contract-fixtures.sh` asserts each SKILL.md references its
  owning contract command (the load-bearing instruction).
- `run-development-plugin-fixtures.sh` asserts the contract-level outcomes
  those skills must produce (verdict files, ledger entries, escalations).

When authoring evals, reuse the fixtures' project builders as the eval
sandbox seed.
