#!/usr/bin/env bash
# Pack the built plugin into a flat single-package tree and push it to the
# `dist` branch, so a consumer can install straight from git:
#
#   dsh plugin add github:my-dsh/dsh-token-usage-dashboard#dist
#
# pnpm installs a git-hosted dependency as ONE package: it prunes any
# node_modules/ inside the checkout (npm-pack rules) and resolves nested
# `file:` dependencies consumer-relatively, so the multi-package workspace
# layout cannot ship through a git branch. The dist branch is therefore a
# FLAT single package that merges the workspace packages:
#
#   package.json      name = the host package name (the listener row's
#                     specifier); dsh carries BOTH `bundle` and `client`;
#                     exports map serves every host subpath plus `./client`
#                     from one root; dependencies keep the host runtime deps
#   cordis.patch.yml  generated: three rows naming the flat root; the client
#                     row is dropped — the browser bundle is served through
#                     the listener row package's `dsh.client` declaration
#   lib/              the host build
#   client.js         the client build
#
# `pnpm run build` must have produced host/lib and client/lib first. Requires
# a built deepseek-harness checkout beside this repository (see BUILD.md)
# because the build resolves @deepseek-ai/* through workspace overrides.
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_URL="$(git config --get remote.origin.url)"
BRANCH=dist
PACK=.dist-pack
BUNDLE=bundle
HOST=host
CLIENT=client

[ -f "$HOST/lib/index.js" ] || { echo "pack-dist: $HOST/lib missing — run pnpm run build first" >&2; exit 1; }
[ -f "$CLIENT/lib/client.js" ] || { echo "pack-dist: $CLIENT/lib/client.js missing — run pnpm run build first" >&2; exit 1; }

rm -rf "$PACK"
mkdir -p "$PACK"
cp -r "$HOST/lib" "$PACK/lib"
cp "$CLIENT/lib/client.js" "$PACK/client.js"

node - "$HOST/package.json" "$CLIENT/package.json" "$BUNDLE/package.json" "$PACK" <<'NODE'
const fs = require('fs')
const [hostPath, clientPath, bundlePath, packDir] = process.argv.slice(2)
const host = JSON.parse(fs.readFileSync(hostPath, 'utf8'))
const client = JSON.parse(fs.readFileSync(clientPath, 'utf8'))
const bundle = JSON.parse(fs.readFileSync(bundlePath, 'utf8'))
const name = host.name
const manifest = {
  name,
  description: bundle.description,
  version: bundle.version,
  publishConfig: { access: 'public' },
  repository: bundle.repository,
  type: 'module',
  main: host.main,
  types: host.types,
  exports: {
    '.': host.exports['.'],
    './invariant': host.exports['./invariant'],
    './sqlite-provider': host.exports['./sqlite-provider'],
    './types': host.exports['./types'],
    './typert': host.exports['./typert'],
    './remote': host.exports['./remote'],
    './service': host.exports['./service'],
    './client': { default: './client.js' },
    './package.json': './package.json',
  },
  dependencies: host.dependencies,
  peerDependencies: { ...host.peerDependencies, ...client.peerDependencies },
  license: bundle.license,
  dsh: { bundle: bundle.dsh.bundle, client: client.dsh.client },
}
fs.writeFileSync(`${packDir}/package.json`, JSON.stringify(manifest, null, 2) + '\n')

// The dist patch: the sqlite/usage/service rows name the flat root (the
// sqlite default path helper is copied from the bundle patch verbatim); the
// client UI rides the usage row's package dsh.client instead of its own row.
const sqlitePath = 'token-usage.sqlite'
const patch = `\
# The dsh-token-usage-dashboard dist patch: flat single-package rows over any
# web-surface profile. The browser panel ships through the token-usage row's
# package dsh.client declaration (no dedicated client row).

- insert:
    - id: token-usage-sqlite
      name: '${name}/sqlite-provider'
      config:
        path: !!js dshHomePath('${sqlitePath}')

    - id: token-usage
      name: '${name}'
      inject: [tokenUsageStore]

    - id: token-usage-remote
      name: '${name}/service'
      inject: [tokenUsageStore]
`
fs.writeFileSync(`${packDir}/cordis.patch.yml`, patch)
NODE

find "$PACK" -name '*.map' -delete

# Stage the pack as an orphan branch — dist never carries repo history.
cd "$PACK"
git init -q
git checkout -q -b "$BRANCH"
git add -A
git -c user.name=pack-dist -c user.email=pack-dist@local commit -q -m "dist: packed from $(git -C .. rev-parse --short HEAD)"
git remote add origin "$REPO_URL"
git push -q --force origin "$BRANCH"
cd ..
rm -rf "$PACK"
echo "pack-dist: pushed $BRANCH to $REPO_URL"
