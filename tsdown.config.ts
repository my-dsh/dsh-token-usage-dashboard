import { defineConfig } from 'tsdown'

/**
 * Standalone workspace build, mirroring the DSH monorepo root config: the
 * Host face bundles the Node halves (host + bundle packages restate their
 * entries in package-local configs), the Client face lets the client
 * package's `clientBundle` preset emit its Node loader entry plus the browser
 * artifact. No Typert plugin here — `lib/typert.*` comes from the monorepo
 * checkout via scripts/sync-typert.sh.
 */
export default defineConfig(({ env }) => {
  const client = env?.DSH_BUILD_FACE === 'client'
  return {
    workspace: ['host', 'client', 'bundle'],
    entry: client ? '' : ['lib/types/{index,invariant}.js'],
    outDir: 'lib',
    format: ['esm'],
    platform: 'node',
    target: 'es2024',
    fixedExtension: false,
    dts: false,
    clean: false,
  }
})
