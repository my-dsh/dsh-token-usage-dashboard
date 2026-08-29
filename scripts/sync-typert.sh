#!/usr/bin/env bash
# Copy the Typert-generated host artifacts from a built deepseek-harness
# checkout. The Typert generator consumes the monorepo's aggregate
# tsconfig.host.json/tsconfig.client.json plus its type graph and cannot run
# from a standalone repository, so `pnpm run build` here never regenerates
# these files; this script refreshes them whenever the service interface
# changes upstream. Diffing keeps a stale checkout from silently winning.
set -euo pipefail

MONOREPO="${1:-$(dirname "$0")/../../../deepseek-harness}"
SRC="$MONOREPO/packages/session/token-usage/lib"
DST="$(dirname "$0")/../host/lib"

for file in typert.host.js typert.host.d.ts typert.remote-client.js typert.remote-client.d.ts; do
  if [ ! -f "$SRC/$file" ]; then
    echo "sync-typert: $SRC/$file is missing — build the monorepo first (pnpm run build:lib:host)" >&2
    exit 1
  fi
  if [ -f "$DST/$file" ] && ! diff -q "$SRC/$file" "$DST/$file" >/dev/null; then
    echo "sync-typert: $file differs from the monorepo build — the service interface changed" >&2
    echo "  run this script again to accept the upstream version" >&2
    exit 1
  fi
  cp "$SRC/$file" "$DST/$file"
  echo "synced $file"
done
