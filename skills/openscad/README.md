# openscad — coding-agent skill

Lets a coding agent (Claude Code / Codex / …) author and modify an **OpenSCAD**
model with nothing installed: the real OpenSCAD (bundled as wasm) renders the
`.scad`, and the agent reads the result back (bbox, volume, triangles, its own
`echo()` lines), looks at it, walks its Customizer parameters, exports STL/3MF
for printing and hands off a link that carries the code — the page behind the
link converts it to STEP.

- **SKILL.md** — the instructions the agent follows. Maintained here; edit it
  directly.
- **bin/cad-build** — launcher for [`@forgent3d/cad-build`](https://www.npmjs.com/package/@forgent3d/cad-build)
  (the same CLI the `forgent3d` skill drives; OpenSCAD ships inside it): runs
  the published package via `npx …@latest`, or a **local build** when
  `FORGENT3D_CAD_BUILD_BIN` points at one.

## Commands

```
cad-build rebuild    part.scad                              # OpenSCAD renders → bbox, volume, triangles, echo()
cad-build snapshot   part.scad [--view front] [--line-art] [--xray]   # orthographic PNG of the render
cad-build knobs      part.scad                              # every Customizer parameter rendered at its extremes
cad-build export     part.scad --format stl                 # stl | 3mf | glb | obj — OpenSCAD's own triangles
cad-build preview    part.scad                              # → shareable link that carries the code (STEP there)
cad-build feedback --message '…' part.scad                  # report a tool bug
```

SKILL.md uses commands and flags of the current `@forgent3d/cad-build` (0.4.0 is
the first with `.scad` input); the launcher always asks npx for `@latest`, so a
new CLI must be **published before** skill text that relies on it is pushed.

## Local build (an engine not yet on npm)

```
pnpm --filter @forgent3d/cad-build build
export FORGENT3D_CAD_BUILD_BIN=/abs/path/to/forgent3d-platform/packages/cad-build-cli/bin/cad-build.mjs
node bin/cad-build rebuild part.scad
```

Unset `FORGENT3D_CAD_BUILD_BIN` to go back to the published package.
