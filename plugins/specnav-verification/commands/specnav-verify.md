---
description: Run the SpecNav verification plugin
argument-hint: "[verification target]"
---

You are using the `specnav-verification` plugin.

Run:

```bash
set -euo pipefail

specnav_env() {
  # Bootstrap: locate the installed specnav-core, then let resolve-runtime.js
  # export every requested SPECNAV_*_ROOT in one call.
  SPECNAV_CORE_ROOT="$(node -e 'const fs=require("fs"),p=require("path"),os=require("os");const b=p.join(os.homedir(),".claude","plugins","cache","specnav-marketplace","specnav-core");let c=[];try{c=fs.readdirSync(b,{withFileTypes:true}).filter(e=>e.isDirectory()).map(e=>p.join(b,e.name)).filter(r=>fs.existsSync(p.join(r,".claude-plugin","plugin.json"))&&!fs.existsSync(p.join(r,".orphaned_at"))).sort((a,z)=>new Intl.Collator(undefined,{numeric:true}).compare(p.basename(z),p.basename(a)))}catch{};if(!c.length){console.error("missing-installed-plugin:specnav-core");process.exit(2)};process.stdout.write(c[0])')"
  eval "$(node "$SPECNAV_CORE_ROOT/scripts/resolve-runtime.js" env --shell "$@")"
}

specnav_env --plugin specnav-core --plugin specnav-development --plugin specnav-verification
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-development --plugin specnav-verification --json
```

If the suite check passes, run the development handoff gate:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json
```

If development is blocked, report the exact blockers and stop. Do not fabricate verification evidence.

If development passes and the handoff JSON reports `light_format: "v2"`, the
single `light-change.json` is the whole verification contract: run static and
unit checks, set each acceptance assertion to `passing` with an
`evidence_ref`, mark tasks done, and record the user's approval in
`user_test` — then run the aggregate command below. Skip the skill files and
the `verify/` packet entirely.

Otherwise, if the lane is `light` (v1 packet), read and follow only these
exact installed-cache skill files. Light lane still requires user-approved
test cases, but its required domains are limited to static and unit:

- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-plan/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-static/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-unit/SKILL.md`

If development passes and the lane is standard or full, read and follow these
exact installed-cache skill files:

- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-plan/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-facticity/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-static/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-unit/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-redteam/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-e2e/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-sensory/SKILL.md`

Do not infer `.claude-plugin/skills/...` paths and do not treat domains as
labels only. Each required domain must create or update its
`verify/<domain>/report.*` artifacts with commands, evidence, findings,
required fixes, and residual risk.

After the domain artifacts exist, run:

```bash
node "$SPECNAV_VERIFICATION_ROOT/scripts/verify-domains.js" aggregate --json
```

The aggregate command writes the machine artifacts:

- `openspec/changes/<change>/verify/aggregate-report.json`
- `openspec/changes/<change>/verify-report.json`

Human-readable md/html renders are NOT written by default — add `--render`
only when the user asks for a review document to share.

Proceed to operations only when `verify/aggregate-report.json.verdict` is
`green`. If the user needs to review with stakeholders, re-run the aggregate
with `--render` and provide the `verify-report.html` path.
