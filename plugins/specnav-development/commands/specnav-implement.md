---
description: Run the SpecNav development plugin
argument-hint: "[task or slice]"
---

You are using the `specnav-development` plugin.

The suite check is required before loading skills. If the suite tool itself is unavailable, report blocker `not-implemented:specnav-core/plugin-suite` and stop.

Run this suite check:

```bash
set -euo pipefail

specnav_env() {
  # Bootstrap: locate the installed specnav-core, then let resolve-runtime.js
  # export every requested SPECNAV_*_ROOT in one call.
  SPECNAV_CORE_ROOT="$(node -e 'const fs=require("fs"),p=require("path"),os=require("os");const b=p.join(os.homedir(),".claude","plugins","cache","specnav-marketplace","specnav-core");let c=[];try{c=fs.readdirSync(b,{withFileTypes:true}).filter(e=>e.isDirectory()).map(e=>p.join(b,e.name)).filter(r=>fs.existsSync(p.join(r,".claude-plugin","plugin.json"))&&!fs.existsSync(p.join(r,".orphaned_at"))).sort((a,z)=>new Intl.Collator(undefined,{numeric:true}).compare(p.basename(z),p.basename(a)))}catch{};if(!c.length){console.error("missing-installed-plugin:specnav-core");process.exit(2)};process.stdout.write(c[0])')"
  eval "$(node "$SPECNAV_CORE_ROOT/scripts/resolve-runtime.js" env --shell "$@")"
}

specnav_env --plugin specnav-core --plugin specnav-development
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-requirements --plugin specnav-prototype --plugin specnav-development --json
```

If the suite check exits non-zero, report the emitted blockers and stop. If it passes, run the shared change triage:

```bash
node "$SPECNAV_CORE_ROOT/scripts/change-triage.js" --intent "${ARGUMENTS:-}" --json
```

If the triage reports `lane: "light"`, create the single-file light change and
run its entry gate in one step (no skill read needed for the default v2 flow):

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-light-change/scripts/create-light-change.js" --intent "${ARGUMENTS:-}" --paths "$INTENDED_PATHS" --json
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json
```

Set `INTENDED_PATHS` to the comma-separated files the change will touch.

This writes ONE `light-change.json` (lane, scope, acceptance, tasks, pending
user test). Cross-repo paths like `../sibling-repo/...` are accepted and
become `external_repos` declarations. Read
`$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-light-change/SKILL.md` only if the
gate blocks or you need the legacy packet (`--format packet`).

For standard and full lanes, run the development contract before any production edit:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json
```

Entry mode proves that upstream requirements, prototype approval, scope, task
packets, and standard checkbox syntax exist. It does not require all `tasks.md`
checkboxes to be complete; unchecked vertical slices are expected before their
implementation evidence exists.

If the entry contract is blocked, read the exact owning skill path and repair
only the allowed development artifacts:

- `$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-development-entry/SKILL.md`
- `$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-scope-lock/SKILL.md`
- `$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-vertical-slices/SKILL.md`

Choose the skill according to the exact blocker. Do not infer a
`.claude-plugin/skills/...` path, do not load similarly named skills from another
plugin, do not fallback to a different change, infer missing upstream decisions,
bypass prototype approval, or continue with production edits while the entry
contract is blocked. Start production edits only after the entry gate returns
`"ok": true`.

Before handoff to verification, run the handoff gate:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json
```

Handoff mode requires every completed slice to have real task reports, spec
review, quality review, ledger entries, drift checks, validation logs, and
`tasks.md` completion evidence. Any `<decision-required>`, "Replace this
scaffold", scaffold source marker, unchecked checkbox, blocking drift, failed
review, or missing validation pass is a blocker. Handoff to verification only
after this handoff gate returns `"ok": true`.
