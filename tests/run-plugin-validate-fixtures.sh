#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "missing-required-tool:claude" >&2
  exit 2
fi

claude plugin validate "$ROOT" >/tmp/specnav-validate-marketplace.out

for plugin in \
  specnav-core \
  specnav-requirements \
  specnav-prototype \
  specnav-development \
  specnav-verification \
  specnav-operations \
  specnav-codegraph; do
  claude plugin validate "$ROOT/plugins/$plugin" >"/tmp/specnav-validate-$plugin.out"
done

echo "specnav plugin validate fixtures ok"
