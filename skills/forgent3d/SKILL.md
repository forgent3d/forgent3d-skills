---
name: forgent3d
description: Author or modify a 3D CAD part for Forgent3D with one CLI, cad-build. Two routes, picked from the request and the files present — a parametric model.py in the build123d dialect, built on the bundled wasm kernel, measured (cad-build rebuild / check), rendered (snapshot), exported to STEP/STL/GLB and published as a shareable 3D link (preview); or an OpenSCAD .scad, rendered by the bundled OpenSCAD (rebuild reads bbox, volume and echo()), snapshotted, its Customizer parameters walked (knobs), exported to STL/3MF, and handed off as a link that carries the code and converts it to STEP. Use whenever the task is creating or changing a 3D CAD part or assembly, previewing or converting a .scad, or a model.py in the build123d dialect or a .scad file is present.
---

# Forgent3D CAD authoring

Two ways to make a part, one CLI. Units are millimetres; the world frame is
right-handed, Z-up.

- **build123d route** — a `model.py` in Forgent3D's build123d + cadkit dialect.
  The kernel builds it as exact B-rep and measures it (bores, faces, walls);
  STEP comes out of this machine; the product's workspace keeps editing it
  (sketches, knobs, assemblies, mates, motion).
- **OpenSCAD route** — a `.scad` the user writes in OpenSCAD. The bundled
  OpenSCAD renders it; you read back bbox, volume and `echo()`, export STL/3MF,
  and hand over a link that carries the code — that page exports STEP.

- **Modeling or modification request** → pick the route, edit the source,
  verify the build.
- **Question** → answer it; change no files.

You edit the source with your own file tools. Everything else — build, measure,
render, export, publish, report bugs — goes through one CLI: `cad-build`.

## Which route: decide first, say it, read one reference

Take the first rule that matches:

1. A `.scad` file is present, or the request names OpenSCAD, `.scad`, the
   Customizer, BOSL2, MCAD or Thingiverse → **OpenSCAD route**. Read
   [references/openscad.md](references/openscad.md).
2. A dialect `model.py` is present (it imports from `build123d` / `cadkit`), or
   the request needs an assembly, mates, motion, a fillet or shell by edge
   selection, a part the product's canvas will edit, measured dimensions, or a
   STEP from this machine → **build123d route**. Read
   [references/build123d.md](references/build123d.md).
3. Neither → **build123d route** (it measures, exports exact STEP and lands in
   the workspace).

Then: read exactly that one reference before editing; keep the route for the
whole task — a `.scad` is never turned into a model.py or the other way round;
name the route in your opening sentence ("Building this in OpenSCAD: …"). When
rule 1 fires but the request also wants mates, motion or a fillet by edge
selection, those need the build123d route: say so and let the user choose —
the one fork here that is worth a question.

| Request | Route |
| --- | --- |
| "A bracket with four M4 holes, STEP for the machine shop" | build123d |
| "Here is my `gridfinity.scad` — make the bin two units taller" | OpenSCAD |
| "Convert this OpenSCAD file to STEP" | OpenSCAD (the preview page does the STEP) |
| "A lid that hinges on this box" | build123d (motion) |
| "A knob in OpenSCAD with BOSL2 rounding and a label" | OpenSCAD |
| "Model a phone stand" (no file, no language named) | build123d |

## Commands

`cad-build` is this skill's `bin/cad-build` wrapper — **not on PATH**, call it
by path: `<this skill's directory>/bin/cad-build`. It runs the published
`@forgent3d/cad-build` via npx (the kernel and OpenSCAD ship inside it: nothing
to install), or a local build when `FORGENT3D_CAD_BUILD_BIN` points at one.

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

| Command | build123d route (`model.py`) | OpenSCAD route (`.scad`) |
| --- | --- | --- |
| `rebuild` | bbox, volume, the cylinder census (each radius **and where its axis runs**), the planar faces (**which coordinate every flat face sits at**), disjoint solids, the solved connections (each mate's kind, outcome, solved frame and derived joint), diagnostics | bbox, volume (the facets'), triangle count, the file's `echo()` lines, OpenSCAD's warnings |
| `check --code` | what your snippet prints against the built model; `def test_*` checks | refused — `echo()` in the file is the probe |
| `snapshot` | the 2×2 sheet (top / iso / front / right) or one `--view`; `--line-art --xray` dashes hidden edges | the same, drawn from OpenSCAD's triangles; `color()` shows |
| `knobs` | every `#@` knob on a constant line, at its extremes: `OK` / `INERT` / `WARNS` / `BROKEN` | every Customizer parameter, re-rendered at its extremes: the same verdicts |
| `export` | STEP (exact), STL / 3MF / GLB / OBJ, written locally | STL / 3MF / GLB / OBJ from OpenSCAD's own triangles; STEP is the preview page's |
| `preview` | uploads model.py, the geometry built here, its colours and any `imports/` files: a link with a 3D view and a browser editor | a link that carries the code itself: real OpenSCAD renders it there, parameters live, STEP and STL export |

Either way a report is a fingerprint, not a verdict: a clean build means it
**compiles**; read the numbers against the request, and **look** (`snapshot`)
before you trust them. The first actionable error names the source line.

The source file may be named anything. Pass its path, or omit it when the
directory holds `model.py`, else exactly one `.py`, else exactly one `.scad`.
`cad-build` keeps derived artifacts in `.cache/` next to the source and the
preview handle in `.forgent3d-preview.json` (a secret) — delete freely, never
edit, gitignore both.

## When the request leaves a decision open

A choice the request leaves open is yours to settle: derive it, measure it, or
take the reasonable default and **build**. Don't stop to confirm a plan you have
already settled on — a part the user can look at beats a question.

What that buys is owed back in the reply, one line each, in the user's own terms:
each **number** you defaulted ("wall 3 mm", "corners R2") — and make it a named
constant (build123d) or a Customizer parameter (OpenSCAD) at the top of the
file — and each **fork** you settled, with the other branch beside it so they
can flip it. Two forks must never go unmentioned, because taking them wrong
costs a rebuild, not a tweak: the size of what the part must **fit** when the
request gives no dimension and no common standard fixes it; and a fork whose
branches are **different parts** (which view a sketch shows, which face mounts
to what, the scale of a photographed object).

## Workflow

1. **Open with one concrete sentence** naming the route and your approach.
2. **Read the route's reference**, then **edit** the source. For a complex
   object, get the main form building clean first, then add features to a base
   known to build — a failure in a short draft names its own cause.
3. **`cad-build rebuild`.** Fix the first actionable error and rebuild until
   clean. Read the report against the request: sizes, positions, every warning.
4. **`cad-build snapshot` and open the PNG.** Numbers confirm dimensions; they
   don't catch a feature on the wrong face or mirrored.
5. **Measure what the report can't** — `check --code` on the build123d route,
   an `echo()` on the OpenSCAD route — only when a value decides your next edit.
6. **Before handing off**: `cad-build knobs` if the file publishes controls and
   fix anything `BROKEN` or `WARNS`. Then `cad-build preview` and hand the user
   the link; `cad-build export` when they need the file itself. Close with the
   defaults and forks you settled.

## Reporting engine/tool bugs

File once with `cad-build feedback --message '…' <the source file>` when you hit
a fault in the **tool or engine itself**: `cad-build` crashes or errors
internally; a valid dialect / cadkit construct the reference says should work
doesn't, or a signature real build123d accepts and the dialect rejects; a `.scad`
that desktop OpenSCAD renders fine is rejected or rendered differently here; the
report states geometry that contradicts correct source; `rebuild` and `preview`
disagree. Passing the file lets the team reproduce it. Keep the message
specific; it is fire-and-forget — send it, then continue or work around it.
A fix may already have shipped, so update first:

```
npx skills update forgent3d               # this skill
npx -y @forgent3d/cad-build@latest help   # refresh the CLI npx cache
```

**Not feedback:** an error caused by your own source — an illegal fillet, a bad
selector, a misplaced cutter, an undefined OpenSCAD variable, a missing include
— is yours to fix. If changing the source can make it right, it's not a tool bug.
