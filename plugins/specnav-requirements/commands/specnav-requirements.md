---
description: Run the SpecNav requirements plugin
argument-hint: "[change intent]"
---

You are using the `specnav-requirements` plugin.

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

specnav_env --plugin specnav-core --plugin specnav-requirements
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-requirements --json
```

If the suite check exits non-zero, report the emitted blockers and stop.

If the suite check passes, read and follow exactly:

```text
$SPECNAV_REQUIREMENTS_ROOT/skills/specnav-requirements/SKILL.md
```

Do not infer a `.claude-plugin/skills/...` path, do not load a similarly named
skill from another plugin, and stop with `missing-skill:specnav-requirements` if
that file is absent.
