# forgent3d-cad — coding-agent skill

Lets a coding agent (Claude Code / Codex / …) author and modify a **Forgent3D**
CAD model: edit a build123d-dialect `model.py`, then build-check / measure it with
the bundled wasm engine and hand off a hosted 3D preview link.

- **SKILL.md** — the instructions the agent follows (generated from Forgent3D's
  production CAD-agent prompt, so it never drifts). Tool-call idioms are rewritten
  to the `cad-build` CLI.
- **bin/cad-build** — launcher for [`@forgent3d/cad-build`](https://www.npmjs.com/package/@forgent3d/cad-build):
  runs the published package via `npx`, or a **local build** when
  `FORGENT3D_CAD_BUILD_BIN` points at one.

## Commands

```
cad-build rebuild [model.py]                    # build-check + dimension report
cad-build run-python [model.py] --code '…'      # measure geometry after the build
cad-build recipe <assembly|selectors|outline>   # focused CAD recipe
cad-build preview [model.py]                     # → hosted 3D viewer link
```

## Local (unpublished) use

Until `@forgent3d/cad-build` is on npm, build it in the monorepo and point the
skill at it:

```
pnpm --filter @forgent3d/cad-build build
export FORGENT3D_CAD_BUILD_BIN=/abs/path/to/forgent3d-platform/packages/cad-build-cli/bin/cad-build.mjs
node bin/cad-build rebuild model.py
```
