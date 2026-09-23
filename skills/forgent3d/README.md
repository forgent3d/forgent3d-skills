# forgent3d — coding-agent skill

Lets a coding agent (Claude Code / Codex / …) author and modify a **Forgent3D**
CAD model: edit a build123d-dialect `model.py`, then build-check / measure / look
at it with the bundled wasm engine and hand off a shareable 3D link.

- **SKILL.md** — the instructions the agent follows. Maintained here; edit it
  directly.
- **references/** — deeper rules the agent reads on demand: `selectors.md`
  (persistent geometry queries), `assembly.md` (mates, joints, the managed
  block), `outline.md` (`#@` annotations and published knobs).
- **bin/cad-build** — launcher for [`@forgent3d/cad-build`](https://www.npmjs.com/package/@forgent3d/cad-build):
  runs the published package via `npx …@latest`, or a **local build** when
  `FORGENT3D_CAD_BUILD_BIN` points at one.

## Commands

```
cad-build rebuild    [file.py]                             # build-check + dimension report
cad-build check      [file.py] --code '…'                  # one-off probe against the built model
cad-build snapshot   [file.py] [--view front] [--line-art] [--xray]   # orthographic PNG
cad-build knobs      [file.py]                             # build every #@ knob at its extremes
cad-build recipe     <motion|pocket|outline>               # focused reference
cad-build export     [file.py] --format step               # step | stl | glb | obj | 3mf
cad-build preview    [file.py]                             # → shareable 3D link
cad-build feedback --message '…' [file.py]                 # report an engine/tool bug
```

SKILL.md uses commands and flags of the current `@forgent3d/cad-build`; the
launcher always asks npx for `@latest`, so a new CLI must be **published before**
skill text that relies on it is pushed.

## Local build (an engine not yet on npm)

Build the CLI in the Forgent3D monorepo and point the skill at it:

```
pnpm --filter @forgent3d/cad-build build
export FORGENT3D_CAD_BUILD_BIN=/abs/path/to/forgent3d-platform/packages/cad-build-cli/bin/cad-build.mjs
node bin/cad-build rebuild model.py
```

Unset `FORGENT3D_CAD_BUILD_BIN` to go back to the published package.
