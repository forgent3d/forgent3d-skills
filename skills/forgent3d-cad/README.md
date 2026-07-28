# forgent3d-cad — coding-agent skill

Lets a coding agent (Claude Code / Codex / …) author and modify a **Forgent3D**
CAD model: edit a build123d-dialect `model.py`, then build-check / measure it with
the bundled wasm engine and hand off a hosted 3D preview link.

- **SKILL.md** — the instructions the agent follows. Maintained here; edit it
  directly.
- **references/** — deeper rules the agent reads on demand: `selectors.md`
  (persistent geometry queries), `assembly.md` (mates, joints, the managed
  block), `outline.md` (`#@` annotations).
- **bin/cad-build** — launcher for [`@forgent3d/cad-build`](https://www.npmjs.com/package/@forgent3d/cad-build):
  runs the published package via `npx`, or a **local build** when
  `FORGENT3D_CAD_BUILD_BIN` points at one.

## Commands

```
cad-build rebuild    [file.py]                 # build-check + dimension report
cad-build run-python [file.py] --code '…'      # measure geometry after the build
cad-build snapshot   [file.py] [--out p.png]   # render a 2x2 orthographic PNG
cad-build preview    [file.py]                 # → hosted 3D viewer link
cad-build feedback --message '…' [file.py]     # report an engine/tool bug
```

## Local (unpublished) use

Until `@forgent3d/cad-build` is on npm, build it in the monorepo and point the
skill at it:

```
pnpm --filter @forgent3d/cad-build build
export FORGENT3D_CAD_BUILD_BIN=/abs/path/to/forgent3d-platform/packages/cad-build-cli/bin/cad-build.mjs
node bin/cad-build rebuild model.py
```
