# forgent3d — coding-agent skill

Lets a coding agent (Claude Code / Codex / …) author and modify a 3D CAD part with
**Forgent3D**, by one of two routes it picks from the request and the files present:

- **build123d route** — edit a build123d-dialect `model.py`, build-check / measure /
  look at it with the bundled wasm engine, export STEP and hand off a hosted 3D link
  (what the product's workspace keeps editing).
- **OpenSCAD route** — edit a `.scad`; the bundled OpenSCAD renders it, the agent reads
  bbox / volume / `echo()` back, walks the Customizer parameters, exports STL/3MF and
  hands off a link that carries the code (that page converts it to STEP).

- **SKILL.md** — what every run reads: the routing rule, the shared command table, the
  shared rules (open decisions, workflow, bug reports). Kept short on purpose.
- **references/build123d.md** / **references/openscad.md** — one of these is read per task,
  as SKILL.md directs: everything specific to that route.
- **references/selectors.md**, **assembly.md**, **outline.md** — deeper build123d rules the
  agent reads on demand (persistent geometry queries; mates, joints, the managed block;
  `#@` annotations and published knobs).
- **bin/cad-build** — launcher for [`@forgent3d/cad-build`](https://www.npmjs.com/package/@forgent3d/cad-build):
  runs the published package via `npx …@latest` (the kernel and OpenSCAD ship inside
  it), or a **local build** when `FORGENT3D_CAD_BUILD_BIN` points at one.

## Commands

```
cad-build rebuild    <file.py | file.scad>                           # build or render, then report
cad-build check      <file.py> --code '…'                            # probe the built model — build123d route only
cad-build snapshot   <file> [--view front] [--line-art] [--xray]     # orthographic PNG
cad-build knobs      <file>                                          # every published control built at its extremes
cad-build export     <file> --format step|stl|3mf|glb|obj            # step: build123d route only
cad-build preview    <file>                                          # → shareable link
cad-build recipe     <motion|pocket|outline>                         # build123d route references
cad-build feedback --message '…' <file>                              # report an engine/tool bug
```

The OpenSCAD route, the `imports/` handling on the build123d route (`import_cad`,
`mesh_bounds`, `mesh_section`, the imports upload in `preview`) and `.scad` input in
general need `@forgent3d/cad-build` **0.4.0 or later**. SKILL.md uses commands and flags
of the current CLI; the launcher always asks npx for `@latest`, so a new CLI must be
**published before** skill text that relies on it is pushed.

## Local build (an engine not yet on npm)

Build the CLI in the Forgent3D monorepo and point the skill at it:

```
pnpm --filter @forgent3d/cad-build build
export FORGENT3D_CAD_BUILD_BIN=/abs/path/to/forgent3d-platform/packages/cad-build-cli/bin/cad-build.mjs
node bin/cad-build rebuild model.py
```

Unset `FORGENT3D_CAD_BUILD_BIN` to go back to the published package.
