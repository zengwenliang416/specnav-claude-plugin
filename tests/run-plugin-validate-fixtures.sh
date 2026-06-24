#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "missing-required-tool:claude" >&2
  exit 2
fi

claude plugin validate "$ROOT" >/tmp/helm-validate-marketplace.out

for plugin in \
  helm-core \
  helm-requirements \
  helm-prototype \
  helm-development \
  helm-verification \
  helm-operations; do
  claude plugin validate "$ROOT/plugins/$plugin" >"/tmp/helm-validate-$plugin.out"
done

echo "helm plugin validate fixtures ok"
