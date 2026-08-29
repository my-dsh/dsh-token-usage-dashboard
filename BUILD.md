# BUILD.md — dsh-token-usage-dashboard

## Repository layout

```
host/     @deepseek-ai/dsh-token-usage — SQLite TokenUsageStore + capture listener + Remote service
client/   @deepseek-ai/dsh-client-token-usage — browser dashboard panel (floating button + modal)
bundle/   @deepseek-ai/dsh-token-usage-dashboard — profile bundle (cordis.patch.yml, 4 rows)
```

## Prerequisites

- Node `^22.19 || >=24`, pnpm 11.
- A built [deepseek-harness](https://github.com/my-dsh/deepseek-harness) checkout at
  `../deepseek-harness` (sibling directory). The workspace overrides in
  `pnpm-workspace.yaml` pin every `@deepseek-ai/*` dependency to that checkout's
  built `lib/` outputs, so no DSH package needs to be published to npm.

## Build

```sh
pnpm install          # resolves @deepseek-ai/* through ../deepseek-harness links
pnpm run build        # tsc -b (host + client faces) then tsdown host + client faces
pnpm run sync-typert  # refresh lib/typert.* from the monorepo build (see below)
```

Outputs:

| Artifact | Consumer |
| --- | --- |
| `host/lib/index.js`, `invariant.js` | Capture plugin + invariant companion (`token-usage` row) |
| `host/lib/sqlite-provider.js` | SQLite provider (`token-usage-sqlite` row; carries `node:sqlite`) |
| `host/lib/remote.js` | Remote service (`token-usage-remote` row; carries `@deepseek-ai/dsh-typert-protocol`) |
| `host/lib/typert.host.js` / `typert.remote-client.js` (+`.d.ts`) | Typert artifacts consumed by `dsh-typert-loader` and `@deepseek-ai/dsh-api-remotes` |
| `client/lib/client.js` | Browser bundle (`window.__ModuleLoader__.load` closure; CSS inlined) |
| `bundle/lib/*`, `bundle/cordis.patch.yml` | The patch layer the profile composer reads |

## Typert artifacts

`lib/typert.host.js` and `lib/typert.remote-client.js` are **not** rebuilt here:
the Typert generator consumes the monorepo's aggregate `tsconfig.host.json` /
`tsconfig.client.json` plus its type graph and cannot run from a standalone
repository. `pnpm run sync-typert` copies them from
`../deepseek-harness/packages/session/token-usage/lib/` and fails loudly when a
copy is missing or already drifted, so a stale checkout never silently wins.
Re-run it whenever the service interface changes upstream.

## Install into a profile

From any directory:

```sh
pnpm dsh plugin --profile web add /home/wuz11/code/github/dsh-token-usage-dashboard/bundle
pnpm dsh plugin --profile web add /home/wuz11/code/github/dsh-token-usage-dashboard/host
```

The bundle's four patch rows (`token-usage-sqlite`, `token-usage`, `token-usage-remote`,
`ui-token-usage`) resolve through the bundle's `workspace:*` dependencies; the
profile boot's module-fallback healer links the whole closure into the shared
`~/.dsh/profiles/node_modules` tree.

The **second add is required**: the running installation's `dsh-api-remotes`
declares `@deepseek-ai/dsh-token-usage` as a peer, so the healer counts the
name as installation-owned and will not project the standalone host package
itself. Installing it as a plain profile dependency gives the profile's own
`node_modules` a direct link that outranks the shared mirror, so the rows load
this repo's build rather than the installation's copy.

Restart the running `dsh web` server afterwards and verify:

```sh
cd deepseek-harness && node --import tsx/esm apps/cli/src/bin.ts web --dump-config | grep token-usage
# expect the four rows; the SQLite row names $DSH_HOME/token-usage.sqlite
```

The dashboard renders as a floating button (bottom-right) in the web GUI; data
is captured per LLM request into `~/.dsh/token-usage.sqlite`.

## Notes

- `node:sqlite` requires Node >= 22.5 (`DatabaseSync`); the profile runtime
  satisfies this.
- Sources are byte-identical to the monorepo copies
  `deepseek-harness/packages/{session/token-usage,client/token-usage,bundle/token-usage-dashboard}`.
