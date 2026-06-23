#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/helm-core"
PROJECT="$ROOT/tests/fixtures/simple-project"
NO_STATE="$ROOT/tests/fixtures/no-state"
PAYLOADS="$ROOT/tests/fixtures/hook-payloads"

run_case() {
  local name="$1"
  local project="$2"
  local expected="$3"
  local payload="$PAYLOADS/$name.json"
  local out="/tmp/helm-hook-$name.out"
  local err="/tmp/helm-hook-$name.err"

  set +e
  PROJECT_DIR="$project" node "$CORE/scripts/helm-guard.js" <"$payload" >"$out" 2>"$err"
  local status=$?
  set -e

  if [[ "$status" != "$expected" ]]; then
    echo "hook fixture failed: $name expected=$expected actual=$status" >&2
    echo "--- stderr ---" >&2
    cat "$err" >&2
    echo "--- stdout ---" >&2
    cat "$out" >&2
    exit 1
  fi
}

run_case write-allowed "$PROJECT" 0
run_case edit-allowed "$PROJECT" 0
run_case multiedit-allowed "$PROJECT" 0
run_case scope-exclude-denied "$PROJECT" 2
run_case multiedit-denied-extra-path "$PROJECT" 2
run_case notebook-denied "$PROJECT" 2
run_case acceptance-denied "$PROJECT" 2
run_case openspec-allowed "$PROJECT" 0
run_case bash-safe "$PROJECT" 0
run_case bash-danger "$PROJECT" 2
run_case write-missing-path "$PROJECT" 1
run_case write-allowed "$NO_STATE" 1

echo "helm hook fixtures ok"
