---
name: forgent3d
description: Author or modify a Forgent3D CAD model by editing a build123d-dialect model.py, then build-check it on the bundled wasm engine and read back its dimensions (cad-build rebuild), see it in four orthographic views (cad-build snapshot), export it (cad-build export → STEP/STL/GLB) and hand off a shareable 3D link (cad-build preview). Use whenever the task is creating or changing a parametric 3D CAD part/assembly for Forgent3D, or when a model.py in the build123d dialect + cadkit is present.
---

# Forgent3D CAD authoring

You are the CAD agent in a Forgent3D project. Units are millimetres; the world
frame is right-handed, Z-up.

- **Modeling or modification request** → edit the source file, then verify the build.
- **Question** → answer it; change no files.

You edit the source with your own file tools. Everything else — build, measure,
render, publish, report bugs — goes through one CLI: `cad-build`.

## Commands

`cad-build` is this skill's `bin/cad-build` wrapper — **not on PATH**, call it
by path: `<this skill's directory>/bin/cad-build`. It runs the published
`@forgent3d/cad-build` via npx, or a local build when `FORGENT3D_CAD_BUILD_BIN`
points at one.

```
cad-build rebuild    [file.py]                 # build-check + dimension report
cad-build check      [file.py] --code '…'      # one-off probe against the built model
cad-build snapshot   [file.py] [--out p.png]   # render a 2x2 orthographic PNG
cad-build export     [file.py] --format step   # step | stl | glb | obj | 3mf
cad-build preview    [file.py]                 # → shareable read-only 3D link
cad-build feedback --message '…' [file.py]     # report an engine/tool bug
```

| Command | Returns | When |
| --- | --- | --- |
| `rebuild` | overall bbox, volume (mm³), per-body bboxes, cylindrical-face census, diagnostics — or the first actionable error | After **every** edit |
| `check --code '…'` | runs your snippet in the built model's namespace and prints what it measures — `checks: N passed[, M failed]`, plus a `FAIL` line per failure | A one-off question `rebuild` and `snapshot` can't answer: a boolean seam, a tangency, an unfamiliar API's real signature |
| `snapshot` | path to a PNG with four orthographic views (front / right / top / iso) | Non-trivial work, or whenever you're unsure the shape looks right |
| `export` | path to the written file, next to the source unless `--out` says otherwise | The user wants the model in another tool: STEP for CAD, STL/3MF for a printer, GLB/OBJ for a viewer |
| `preview` | a shareable 3D link for the user | When the model is done and verified |
| `feedback` | nothing (fire-and-forget) | A fault in the tool or engine itself |

### File argument

The source file may be named anything — `bracket.py`, `part.py`, whatever fits.
Pass its path, or omit it when the directory holds exactly one `.py` or the file
is named `model.py`. Whatever the name, `cad-build` builds it as the model.

### check --code: a throwaway probe against the built model

`check --code '…'` (or `--code-stdin`) builds the model, then runs your snippet
as if appended to the source: every top-level name — bodies, intermediate
locals, dimension constants, `model` — is in scope. Top-level statements run
first; then every top-level `def test_*` runs in definition order, each
isolated, so one failure reports and the rest still run. `assert` is allowed
here and **only** here (the model source still rejects it); a bare
`assert cond` reports its own source text when it fails.

Reach for it when a value decides your next edit and steps 3–4 can't supply it
— a boolean seam, a tangency, whether a cutter really cleared a wall — or to
pin down an unfamiliar API with a minimal call before using it in the model.
`print()` the measurement instead of guessing.

Batch every open question into one snippet, and write each independent question
as its own `def test_*`: the runner isolates them, so one wrong API guess fails
only that check instead of the whole batch.

Deferred `*_feature` results (shell, fillet) are applied before the snippet
runs, so measure through the Body (`body.geometry`) — an intermediate local
still holds the pre-feature shape.

**Snippets are never saved, and that is the point.** Don't write a test file
into the user's project, and don't leave probe scaffolding behind: the source
file is the only artifact this skill produces. Real changes go in the model
source.

### preview publishes a read-only link

`preview` builds the model here, uploads the source and that geometry, and returns
a link **anyone can open without signing in** — a 3D view they can rotate and
measure, not an editable model. To edit it in the cloud, the user signs in on that
page and remixes it, which copies it into their own account; the copy is theirs and
this project no longer touches it.

The link is stable across runs: `preview` writes `.forgent3d-preview.json` in the
project dir, and re-previewing **updates the same link** rather than spawning a new
one, so a link already sent to someone stays current. That file holds a **secret**
— it's what authorizes replacing the model behind the link, so gitignore it rather
than committing it to a public repo. Losing it costs only a new link.

`cad-build` also keeps derived build artifacts in a `.cache/` directory next to
the source — safe to delete, never edit, gitignore it alongside the preview file.

### export is fully local

`export` runs on the same bundled engine, writes the file next to the source, and
talks to nothing. Use it whenever the user wants the part itself — STEP into their
CAD tool, STL or 3MF to print, GLB to open in any glTF viewer.

## The source file — the only editable truth

It must assign a global `model`. Canonical shape:

~~~python
"""Plate with mounting bores. Body-local geometry, world Z-up, mm."""
from build123d import BuildSketch, Circle, Locations, Mode, Plane, Rectangle, extrude
from cadkit import Appearance, Body, Model

plate_w = 100.0
bore_inset = 10.0

with BuildSketch(Plane.XY) as plate_profile:
    Rectangle(plate_w, 70.0)
    with Locations((-plate_w / 2 + bore_inset, 0), (plate_w / 2 - bore_inset, 0)):
        Circle(4.0, mode=Mode.SUBTRACT)
plate = Body("plate", geometry=extrude(plate_profile.sketch, amount=8.0),
             appearance=Appearance(color="#777777", material="aluminum"))
model = Model(bodies=[plate])
~~~

## Modeling rules

- **Docstring first.** The module docstring's first sentence names the model;
  then state axes and datum.
- **Geometry outranks presentation.** Model the shape the way it actually wants
  to be built.
- **Respect geometric legality before you build.** A fillet or corner radius must
  be strictly less than half the shorter side it rounds; a counterbore shallower
  than the wall it enters; a cutter fully through what it cuts. Clamp with
  `min()` / `max()` rather than hoping a nominal number fits; to hard-fail
  instead, `if not cond: raise ValueError(…)` — the model dialect has no
  `assert` (a `check --code` snippet does).
- **Two silent traps** (build fine, bite later): an overshooting cutter can
  gouge an unrelated thin wall beside its target — the census won't show it, the
  snapshot will; a sketch extrudes along **its own plane's** normal, so on an
  offset plane check the rebuild bbox rather than assuming a world axis.
- **Sketch-first.** Draw the outline with `BuildSketch` on `Plane.XY` / `XZ` /
  `YZ`, subtract holes and slots inside the same sketch, then `extrude` /
  `revolve` / `sweep` / `loft`. This is the default construction and the only one
  editable on the product's 2D canvas — a primitive stays editable while centred,
  unrotated, and placed via literal coordinates in `Locations`. Reach for
  `Box` / `Cylinder` / … only for genuinely primitive stock or boolean cutters.
- **Prefer cadkit's labelled helpers** — `safe_add`, `safe_cut`, `safe_union`,
  `safe_fillet`, `safe_chamfer(..., label="feature")` — over raw booleans. A
  failing guard means the placement is wrong: fix it. Never shave, shift or
  delete geometry to silence a check. `[cadkit]` notes in the rebuild output
  are real (a capped radius, a skipped optional round) — read them.

## Working from a drawing

When the request is a dimensioned engineering drawing, the dominant failure mode
is not building wrong — it's *reading* wrong. Treat interpretation as its own
verified step:

- **Get the drawing as a file first.** A pasted image can't be zoomed, and
  hairline extension lines can't be traced at full-sheet scale. Ask for the
  image file (or save it next to the source file — it also serves the next
  session) before committing any geometry.
- **Zoom every ambiguous dimension.** Crop the region (sips, ImageMagick, a
  3-line PIL script) and read the crop. Which line an extension line touches,
  stacked-dim datums, which face a depth is cut from, which side of a step is
  the wide one — decide these from a zoomed crop, never from drafting-convention
  guesswork alone.
- **Balance the dimension ledger.** List every dimension on the sheet and the
  feature that consumes it. A correct reading consumes each exactly once: a
  leftover dim means a misread feature; a feature you need but can't dimension
  from the sheet means a wrong interpretation. These drawings are fully defined.
- **Compare snapshot views against drawing views.** Same projections, side by
  side — proportion mismatches (a neck too long, a flange too far out) expose
  path and datum misreads that no bbox number will.
- **Price the residual ambiguity.** If a reading still can't be pinned, model
  the most defensible one and report the alternative with its consequence
  ("if that .25 is from the outer face instead, mass drops to 4.16 lb") so the
  user can arbitrate at full resolution.

## Reference docs

Three areas have rules that don't fit here. **Read the file before you touch that
area** — each is short, and getting these wrong produces models the product can't
edit later.

| File | Read it before |
| --- | --- |
| [references/selectors.md](references/selectors.md) | Writing any persistent geometry reference — `selector.…` queries, `Body(features={…})`, mate sides |
| [references/assembly.md](references/assembly.md) | Poses, mates, joints, connectors, `Reference`/`MeshRef`, persistent appearance overrides, the `# <forgent3d:assembly>` managed block |
| [references/outline.md](references/outline.md) | Adding or editing a `#@` annotation — outline labels, and knobs on a constant line (the generator panel) |

## Workflow

1. **Open with one concrete sentence** stating your approach. No generic
   acknowledgements.
2. **Edit** the source file.
3. **`cad-build rebuild`.** Fix the first actionable error and rebuild until
   clean. Read the returned bboxes and hole census to confirm sizes and placement
   match the request.
4. **`cad-build snapshot` and open the PNG.** Numbers confirm dimensions, but
   they don't catch a shape that's wrong in a way the bbox can't see — a bore on
   the wrong face, a feature mirrored, a fillet that didn't take. The four views
   let you *see* what you built and compare it against what was asked. It reads
   from the same build as `rebuild`, so run it once the build is clean.
5. **`cad-build check --code '…'`** when a value decides your next edit and
   steps 3–4 can't supply it (a boolean seam, a tangency, an API you haven't
   used before) — `print()` the measurement instead of guessing. Skip it
   otherwise; it leaves nothing behind either way.
6. **`cad-build preview`** and hand the user the link. Add `cad-build export` when
   they need the geometry itself rather than a link.

## Reporting engine/tool bugs

File once with `cad-build feedback --message '…' <the source file>` when you hit
a fault in the **tool or engine itself**:

- `cad-build` crashes or errors internally.
- A valid dialect/cadkit construct that the docs say should work doesn't.
- **A signature gap** — real build123d accepts the call, the dialect doesn't (or
  takes the argument and ignores it). Fixed in the engine, not worked around in
  the model: it ships as a new `@forgent3d/cad-build` + skill, so update and
  retry before filing.

  ```
  npx skills update forgent3d               # this skill (`npx skills list` shows where)
  npx -y @forgent3d/cad-build@latest help   # refresh the CLI npx cache
  ```

  `bin/cad-build` already asks npx for `@latest`; only a
  `FORGENT3D_CAD_BUILD_BIN` local build is pinned — rebuild it, or unset it.
- The build summary reports geometry that contradicts correct source.
- `rebuild` and `preview` disagree.

This reaches the Forgent3D team through the same channel as the product's in-app
feedback widget; passing the source file lets them reproduce it. Keep the message
specific: what you did, what you expected, what happened. It's fire-and-forget —
send it, then continue or work around the issue. Don't block the user's task on it.

**Not feedback:** a build error caused by your own model — an illegal fillet, a
bad selector, a misplaced cutter — is yours to fix. If changing the source can
make it right, it's not a tool bug.
