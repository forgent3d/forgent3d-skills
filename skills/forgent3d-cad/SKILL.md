---
name: forgent3d-cad
description: Author or modify a Forgent3D CAD model by editing a build123d-dialect model.py, then build-check and measure it with the bundled wasm engine (cad-build rebuild / run-python) and hand off a hosted 3D preview link (cad-build preview). Use whenever the task is creating or changing a parametric 3D CAD part/assembly for Forgent3D, or when a model.py in the build123d dialect + cadkit is present.
---

# Forgent3D CAD authoring

You are the CAD agent in a Forgent3D project. Units are millimetres; the world
frame is right-handed, Z-up.

- **Modeling or modification request** → edit the source file, then verify the build.
- **Question** → answer it; change no files.

You edit the source with your own file tools. Everything else — build, measure,
render, publish, report bugs — goes through one CLI: `cad-build`.

## Commands

```
cad-build rebuild    [file.py]                 # build-check + dimension report
cad-build run-python [file.py] --code '…'      # measure geometry after the build
cad-build snapshot   [file.py] [--out p.png]   # render a 2x2 orthographic PNG
cad-build preview    [file.py]                 # → hosted link; imports into the account
cad-build feedback --message '…' [file.py]     # report an engine/tool bug
```

| Command | Returns | When |
| --- | --- | --- |
| `rebuild` | overall bbox, per-body bboxes, hole census, diagnostics — or the first actionable error | After **every** edit |
| `run-python` | whatever the snippet `print()`s, run in the model's namespace after it builds | Only when a value can't be derived from the source or the rebuild summary |
| `snapshot` | path to a PNG with four orthographic views (front / right / top / iso) | Non-trivial work, or whenever you're unsure the shape looks right |
| `preview` | a hosted 3D link for the user | When the model is done and verified |
| `feedback` | nothing (fire-and-forget) | A fault in the tool or engine itself |

`cad-build` is this skill's `bin/cad-build` wrapper: it runs the published
`@forgent3d/cad-build` via npx, or a local build when `FORGENT3D_CAD_BUILD_BIN`
points at one.

### File argument

The source file may be named anything — `bracket.py`, `part.py`, whatever fits.
Pass its path, or omit it when the directory holds exactly one `.py` or the file
is named `model.py`. Whatever the name, `cad-build` builds it as the model, and
`preview` imports it into the product as that model's `model.py`.

### run-python is ephemeral

Snippets run after the build and are never saved — real changes go in the source
file. Each call costs a round-trip: batch every open question into one snippet,
and skip it entirely when the `rebuild` summary already answers. Large snippets
can come from stdin with `--code-stdin`.

### preview is stable across runs

`preview` writes `.forgent3d-preview.json` in the project dir, holding a stable
key that ties this project to one cloud model — so re-previewing after edits
**updates that same model in place** instead of spawning a duplicate. Keep the
file between previews; it carries no secrets and is safe to commit or gitignore.

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
  `min()` / `max()` rather than hoping a nominal number fits.
- **Sketch-first.** Draw the outline with `BuildSketch` on `Plane.XY` / `XZ` /
  `YZ`, subtract holes and slots inside the same sketch, then `extrude` /
  `revolve` / `sweep` / `loft`. This is the default construction and the only one
  editable on the product's 2D canvas — a primitive stays editable while centred,
  unrotated, and placed via literal coordinates in `Locations`. Reach for
  `Box` / `Cylinder` / … only for genuinely primitive stock or boolean cutters.
- **Prefer cadkit's labelled helpers** — `safe_add`, `safe_cut`, `safe_union`,
  `safe_fillet`, `safe_chamfer(..., label="feature")` — over raw booleans. A
  failing guard means the placement is wrong: fix it. Never shave, shift or
  delete geometry to silence a check.

## Reference docs

Three areas have rules that don't fit here. **Read the file before you touch that
area** — each is short, and getting these wrong produces models the product can't
edit later.

| File | Read it before |
| --- | --- |
| [references/selectors.md](references/selectors.md) | Writing any persistent geometry reference — `selector.…` queries, `Body(features={…})`, mate sides |
| [references/assembly.md](references/assembly.md) | Poses, mates, joints, connectors, `Reference`/`MeshRef`, persistent appearance overrides, the `# <forgent3d:assembly>` managed block |
| [references/outline.md](references/outline.md) | Adding or editing a `#@` annotation |

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
5. **`cad-build run-python`** only for what steps 3–4 can't answer (a boolean
   seam, a tangency) — `print()` the measurement instead of guessing.
6. **`cad-build preview`** and hand the user the link.

## Reporting engine/tool bugs

File once with `cad-build feedback --message '…' <the source file>` when you hit
a fault in the **tool or engine itself**:

- `cad-build` crashes or errors internally.
- A valid dialect/cadkit construct that the docs say should work doesn't.
- The build summary reports geometry that contradicts correct source.
- `rebuild` and `preview` disagree.

This reaches the Forgent3D team through the same channel as the product's in-app
feedback widget; passing the source file lets them reproduce it. Keep the message
specific: what you did, what you expected, what happened. It's fire-and-forget —
send it, then continue or work around the issue. Don't block the user's task on it.

**Not feedback:** a build error caused by your own model — an illegal fillet, a
bad selector, a misplaced cutter — is yours to fix. If changing the source can
make it right, it's not a tool bug.
