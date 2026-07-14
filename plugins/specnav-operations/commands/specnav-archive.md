---
description: Archive a SpecNav change after verification and operations gates pass
argument-hint: "[change name]"
---

Run:

```bash
set -euo pipefail

specnav_env() {
  # Bootstrap: locate the installed specnav-core, then let resolve-runtime.js
  # export every requested SPECNAV_*_ROOT in one call.
  SPECNAV_CORE_ROOT="$(node -e 'const fs=require("fs"),p=require("path"),os=require("os");const b=p.join(os.homedir(),".claude","plugins","cache","specnav-marketplace","specnav-core");let c=[];try{c=fs.readdirSync(b,{withFileTypes:true}).filter(e=>e.isDirectory()).map(e=>p.join(b,e.name)).filter(r=>fs.existsSync(p.join(r,".claude-plugin","plugin.json"))&&!fs.existsSync(p.join(r,".orphaned_at"))).sort((a,z)=>new Intl.Collator(undefined,{numeric:true}).compare(p.basename(z),p.basename(a)))}catch{};if(!c.length){console.error("missing-installed-plugin:specnav-core");process.exit(2)};process.stdout.write(c[0])')"
  eval "$(node "$SPECNAV_CORE_ROOT/scripts/resolve-runtime.js" env --shell "$@")"
}

specnav_env --plugin specnav-core --plugin specnav-operations
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-verification --plugin specnav-operations --json
SPECNAV_ARCHIVE_ARGS="${ARGUMENTS:-}" node "$SPECNAV_OPERATIONS_ROOT/scripts/archive-change.js" --json
```

Archive only when the command returns `ok: true`. The command normalizes
`tasks.md`, requires a green operations archive gate, validates the change with
`openspec validate`, executes `openspec archive`, updates SpecNav registry/focus
state, and writes `operations/archive-receipt.json` under the archived change.
For `lane: "light"`, the archive gate uses the compact evidence contract:
checked `tasks.md`, passing `acceptance.json` evidence, approved
`verify/user-test-case-signoff.json`, green `verify/aggregate-report.json`, and
`light-gate.json`. It does not require the full operations readiness document
set.
If `tasks-md.js normalize` changes the file but exits with
`tasks-md:incomplete-checkboxes`, stop and tell the user the task file has been
converted to standard checkbox syntax and now needs explicit `- [x]` completion
evidence. Do not describe plain bullets as completed tasks. Do not use native
OpenSpec skills; using the `openspec` CLI is allowed.
