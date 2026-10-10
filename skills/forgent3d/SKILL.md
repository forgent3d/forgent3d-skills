---
name: forgent3d
description: Author or modify a Forgent3D CAD model by editing a build123d-dialect model.py, then build-check it on the bundled wasm engine and read back its dimensions (cad-build rebuild), measure it (cad-build check), see it in orthographic views (cad-build snapshot), export it (cad-build export → STEP/STL/GLB) and hand off a shareable 3D link (cad-build preview). A STEP/BREP the user supplies is imported as real geometry (import_cad), an STL is shown and read (MeshRef, mesh_section) to build around it. Use whenever the task is creating or changing a parametric 3D CAD part/assembly for Forgent3D, or when a model.py in the build123d dialect + cadkit is present.
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
cad-build rebuild    [file.py]                             # build-check + dimension report
cad-build check      [file.py] --code '…'                  # one-off probe against the built model
cad-build snapshot   [file.py] [--view front] [--line-art] [--xray]   # orthographic PNG
cad-build knobs      [file.py]                             # build every #@ knob at its extremes
cad-build recipe     <motion|pocket|outline>               # focused reference for one kind of request
cad-build export     [file.py] --format step               # step | stl | glb | obj | 3mf
cad-build preview    [file.py]                             # → shareable 3D link
cad-build feedback --message '…' [file.py]                 # report an engine/tool bug
```

| Command | Returns | When |
| --- | --- | --- |
| `rebuild` | bbox, volume (mm³), the cylinder census (each radius **and where its axis runs**), the planar faces (**which coordinate every flat face sits at**), disjoint solids, per-body bboxes, diagnostics — or the first actionable error | After **every** edit |
| `snapshot` | path to a PNG: the 2×2 sheet (top / iso / front / right), or one `--view` | Once it builds clean — to *see* it before you measure it |
| `check --code '…'` | what your snippet prints in the built model's namespace; `checks: N passed[, M failed]` for `def test_*` checks | A value the report can't answer: a seam, a wall, a tangency, an unfamiliar API's real behaviour |
| `knobs` | every published `#@` knob built at its extremes: `OK` / `INERT` / `WARNS` / `BROKEN` | Before handing off a model that publishes knobs |
| `recipe <name>` | the product's own reference for that kind of request | When its trigger below is true of the request |
| `export` | path to the written file, next to the source unless `--out` says otherwise | The user wants the part in another tool: STEP for CAD, STL/3MF for a printer, GLB/OBJ for a viewer |
| `preview` | a shareable 3D link for the user | When the model is done and verified |
| `feedback` | nothing (fire-and-forget) | A fault in the tool or engine itself |

### File argument

The source file may be named anything — `bracket.py`, `part.py`, whatever fits.
Pass its path, or omit it when the directory holds exactly one `.py` or the file
is named `model.py`. Whatever the name, `cad-build` builds it as the model.

### Reading the rebuild report

The report is a fingerprint of the solid, not a verdict: a clean build means it
**compiles**, not that it is right. Read it against the request. A bore at the
right radius but the wrong position shows up in the cylinder line's `@ x… y…`; a
step cut to the wrong depth shows up as a missing or misplaced offset in the
planar-face line; a `disjoint solids` line means a body came apart (a fillet or a
cut severed a boss). Every `warning` in `diagnostics` is real:

- `fillet-capped` / `chamfer-capped` / `*-skipped` — a cadkit helper delivered
  **less** than you asked for. Reshape the neighbourhood so the real dimension
  fits rather than accepting the capped value.
- `body-interference` — two bodies share volume. A real defect, not noise: fix
  the gap or the placement, never raise a tolerance. Touching is fine and does
  not appear.
- `unused-variable`, `seam-embedded`, `pocket-*` and the rest say what they mean —
  read them; a dimension that never reaches the geometry is usually a typo.

### check --code: a throwaway probe against the built model

`check --code '…'` (or `--code-stdin`) builds the model, then runs your snippet
as if appended to the source: every top-level name — bodies, intermediate
locals, dimension constants, `model` — is in scope, and so is cadkit's `measure`.
Top-level statements run first; then every top-level `def test_*` runs in
definition order, each isolated, so one failure reports and the rest still run.
`assert` is allowed here and **only** here (the model source still rejects it); a
bare `assert cond` reports its own source text when it fails.

**Isolate before you iterate.** Once the same operation has failed twice, or you
are unsure how an API behaves, stop editing the model and rebuild just that step
here as a minimal case, printing what it actually produces (edge count, area,
volume, validity). One isolated probe pins the failing step; another blind
whole-model rebuild does not.

**Measure with `measure`, not with hand-filtered `.faces()` / `.edges()`** — one
condition too loose and an unrelated face averages into a number that is wrong
but plausible. `dir()` works but signatures don't, so this is the API. Every
reader takes the model, one body, or a raw Part:

- `measure.span(model, "Z")` — overall extent along an axis.
- `measure.plane_at(model, "Z", 44)` — the face at that coordinate, or `None`;
  `None` **is** the finding. `measure.step(model, "Z", 50, 44)` — the distance,
  raising unless both faces exist.
- `measure.cylinders(model, radius=13)` — a **list** of grouped entries: index it
  (`[i].count`), never call `.count` on the list. A full bore groups by its axis
  line (three Ø13 through-holes = three entries of count 1); a partial arc (a
  fillet) has no position and appears **only** with `include_partial=True` (four
  R2.5 corner blends = one entry of count 4). `[i].at("Z")` is the axis
  position.
- `measure.edges(model, kind=, radius=, axis=)` / `measure.edges_at(model, "X",
  69, radius=16.5)` — **which edge**: name an edge by radius and position before
  rounding it, never by an index into `.edges()`.
- `measure.walls(model)` — every material thickness it can prove (two opposed
  faces). Where a wall **wraps** a feature, check the derived surface exists
  instead (an R15 clearance in a 6 mm wall leaves an R21 face).
- `measure.slopes(model)` — ramp angles. `measure.interference(model)` — bodies
  sharing space (or pass two parts: a posed body and its neighbour).
- `print(measure.report(model))` — every plane, bore, wall, edge and interference
  the solid actually has, to read against the request line by line.

A grouped entry prints its whole story (`print(g)`); its fields are fixed: a plane
`.axis .offset .count .area .facing`; a cylinder `.radius .axis .position .count
.area .sweep .full` + `.at(axis)`; a wall `.thickness .kind .axis .low .high
.position .count .area`; an interference pair `.a .b .volume .min .max`.

Batch every open question into one snippet, and write each independent question
as its own `def test_*`: the runner isolates them, so one wrong API guess fails
only that check instead of the whole batch. Assert against the **built**
geometry — asserting a constant against itself proves nothing.

Deferred `*_feature` results (shell, fillet, pocket) are applied before the
snippet runs, so measure through the Body (`body.geometry`) or the model — an
intermediate local still holds the pre-feature shape.

**Snippets are never saved, and that is the point.** Don't write a test file
into the user's project, and don't leave probe scaffolding behind: the source
file is the only artifact this skill produces. Real changes go in the model
source.

### snapshot: views and the drawing dress

With no flags, `snapshot` renders the 2×2 third-angle sheet — top-left TOP,
top-right ISO, bottom-left FRONT, bottom-right RIGHT SIDE. The three orthographic
views share one scale and one centre (a column is the same X, a row the same Z),
so a feature can be matched across them. `--view top|front|right|left|back|bottom|iso`
renders one view alone at full size: for a detail too small on the sheet, or a
face the sheet never shows (left/back/bottom).

A shaded render only draws **visible** outlines — never conclude a hole or pocket
is missing from one. `--line-art --xray` draws the orthographic views as a line
drawing with the edges hidden behind material **dashed**, the way a drawing does:
a cavity, a wall thickness, a bore that stops all appear. That is the view to hold
beside an engineering drawing, one projection at a time.

### knobs: does every published control survive its range?

A `#@` knob is a promise to whoever opens the model's link: this slider runs
from here to there, this switch flips, each of these options builds. `knobs`
moves each one alone to its extremes — both ends of its range, the other switch
state, every dropdown option — and rebuilds. `BROKEN` means a visitor dragging
that control there gets a failed build; `WARNS` means the part still builds
there but degraded (a warning the default does not raise, or a body in pieces);
`INERT` means the control moves nothing. Run it before you hand off a model with
knobs: nothing else ever builds a value other than the default. Two knobs at
their extremes together are not built.

### preview publishes a shareable link

`preview` builds the model here, uploads the source, that geometry and its
colours/materials, and returns a link **anyone can open without signing in**: a
3D view of the part, and a browser editor where they can turn its `#@` knobs —
rebuilt in their own browser, **never saved**. To keep an edited copy, the user
signs in on that page and remixes it into their own account; the copy is theirs
and this project no longer touches it.

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
- **Imports are static, at the top of the file** — `import math`,
  `from math import radians, tan`. The dialect has no `__import__`: a module is
  reachable only through a top-level import statement.
- **Geometry outranks presentation.** Model the shape the way it actually wants
  to be built. Every dimension the request states is binding: reproduce it
  exactly and derive the rest from it rather than eyeballing.
- **Pick each component's construction route from the shape it is.** A body of
  revolution is revolved about its axis; a stack of blocks with bores and bosses
  is those solids combined; a constant cross-section running along a path is
  swept; a profile no combination of solids spells — a genuine outline — is drawn
  flat (`BuildSketch` on `Plane.XY` / `XZ` / `YZ`, holes and slots subtracted in
  the same sketch) and extruded. The example above is a sketch because it has to
  be written some way; it is a demonstration, not a default. What stays editable
  later: a sketch outline (its vertices drag on the product's 2D canvas) and a
  centred, unrotated primitive placed by literal `Locations` coordinates.
  Primitives stacked at computed coordinates are editable nowhere.
- **Primitives are built centred on the origin**, so
  `Cylinder(r, h).moved(Pos(0, 0, z))` spans `z - h/2 .. z + h/2`. Don't do that
  arithmetic by hand: `stand_on(shape, z)` seats a shape **on** the datum at z,
  `hang_from(shape, z)` hangs it **under** one (the right form for a bore entering
  a top face); a cutter spanning z0..z1 is `stand_on(Cylinder(r, z1 - z0), z0)`.
  `.moved()` takes only a Location and `.rotate()` only an Axis —
  `.moved(Pos(x, y, z))`, `.rotate(Axis.Z, degrees)`; a bare tuple is neither.
- **A stated wall thickness is a shell, not two solids.** Build the outer shape
  complete, then hollow it once:
  `safe_shell(part, part.faces().filter_by(Axis.Z).sort_by(Axis.Z)[-1], 2.0, label="wall")`
  opens the top. Every inner radius follows from that offset; authoring one, or
  subtracting a hand-built cavity, punches through the wall wherever an outer
  recess is deeper than it — and the part still builds and measures right
  outside. Shell before rounding edges that run into the opened face; cut what
  pierces the finished wall after.
- **Respect geometric legality before you build.** A fillet or corner radius must
  be strictly less than half the shorter side it rounds; a counterbore shallower
  than the wall it enters; a cutter fully through what it cuts. Clamp a derived
  value with `min()` / `max()` rather than hoping it fits; to hard-fail instead,
  `if not cond: raise ValueError(…)` — the model dialect has no `assert`. A value
  taken from a drawing is ground truth: when it does not fit, the surrounding
  geometry is misread — fix that, never clamp it away.
- **Two silent traps** (build fine, bite later): an overshooting cutter can
  gouge an unrelated thin wall beside its target — the census won't show it, the
  snapshot will; a sketch extrudes along **its own plane's** normal, so on an
  offset plane check the rebuild bbox rather than assuming a world axis.
- **Prefer cadkit's labelled helpers** — `safe_add`, `safe_cut`, `safe_union`,
  `safe_fillet`, `safe_chamfer`, `safe_shell(..., label="feature")` — over raw
  booleans. A failing guard means the placement is wrong: fix it. Never shave,
  shift or delete geometry to silence a check.
- **Bodies may not share volume.** Parts that must fit together need clearance,
  never a shared nominal. `body-interference` is the only check that looks
  across bodies, and it only sees the pose the source writes — a part that must
  **move** needs the `motion` recipe.

## Files the user hands you

A STEP, BREP or STL the user gives you is a **build input**, not something to
redraw: copy it to `imports/<name>.<ext>` beside the source file (a plain name,
one level deep), reference it by that relative path, and never edit or
regenerate what is in `imports/`. Then:

- **STEP / BREP** — `cadkit.import_cad("imports/<file>")` returns real solid
  geometry: select its faces, `safe_fillet` / `safe_chamfer` its edges, cut, fuse,
  mate and measure it like a part you built; the rebuild censuses read its
  bores and faces too. A multi-solid file comes back as a Compound — assign it to
  one Body as it is, or split it with `.solids()` and name the pieces. A big STEP
  is parsed on every build (a 7 MB board takes about ten seconds).
- **STL** — a triangle mesh: it takes no booleans, and the censuses and `measure`
  do not see it. `MeshRef(file="imports/<file>", transform=Transform(pos=…))`
  under `Assembly(mesh_refs={…})` in the managed block shows it (`pos` is where
  its bounding-box centre lands); the report lists it under `mesh refs`. To build
  AROUND it, read it: `cadkit.mesh_bounds(path)` gives `(lo, hi)`, and
  `cadkit.mesh_section(path, z=None, tol=0.05)` gives the closed outline Wire(s)
  of the cut at z (default mid-height), largest first —
  `offset(make_face(outline), amount=clearance)` is the exact perimeter a tray,
  lid, pocket or holder must follow. When the user has both a photo and the
  file, the file wins: a section is exact, a trace is not.
- `preview` uploads the `imports/` files model.py names along with the geometry,
  so the link shows the mesh and a remix can rebuild. `export` writes the B-rep
  only: an imported STEP is in it, a mesh ref is shown, not merged.

## When the request leaves a decision open

A choice the request leaves open is yours to settle: derive it, measure it, or
take the reasonable default and **build**. Don't stop to confirm a plan you have
already settled on — a part the user can look at beats a question.

What that buys is owed back in the reply, one line each, in the user's own terms:
each **number** you defaulted ("wall 3 mm", "corners R2") — and make it a named
constant at the top of the file — and each **fork** you settled, with the other
branch beside it so they can flip it. Two forks must never go unmentioned,
because taking them wrong costs a rebuild, not a tweak:

- the size of what the part must **fit** — what it attaches to, holds, covers,
  plugs into or replaces — when the request gives no dimension and no common
  standard fixes it. "A lid for a pot", "a stand for a phone" name the thing, not
  its size: build the commonest one and say which you took;
- a fork whose branches are **different parts**: which view a sketch shows, which
  face mounts to what, the scale of a photographed object with nothing to scale
  it by.

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
- **Look before you measure.** Once it builds clean, compare the model with the
  sheet projection by projection — the sheet's plan view against
  `snapshot --view top --line-art --xray`, its front elevation against
  `--view front`, its isometric against the sheet's ISO cell. Same outline, same
  feature count, same proportions. A part built off a misread datum passes every
  measurement you write, because those came from your own reading; it only looks
  wrong next to the sheet. A mismatch is a lead to re-read that callout, never
  something to nudge the model until the picture agrees.
- **Price the residual ambiguity.** If a reading still can't be pinned, model
  the most defensible one and report the alternative with its consequence
  ("if that .25 is from the outer face instead, mass drops to 4.16 lb") so the
  user can arbitrate at full resolution.

## Recipes

`cad-build recipe <name>` prints the product's own reference for one kind of
request, shipped with the engine version you are running. Load one when its
condition is true of the request in front of you — and only then:

- **`motion`** — the request asks for a **mechanism**: a part that must swing,
  slide or turn against another after it is built — a lid or door on a hinge, a
  drawer, a printed joint. Load it **before** you place the pivot: nothing in the
  build report can see a mechanism bind. Not needed for a static fit (a tab in a
  slot, a lift-off lid).
- **`pocket`** — the request asks for a holder, tray, dock, organizer or case
  insert that a **named object** drops into and must fit: a phone, a camera, a
  bottle, a tool. Load it before drawing the cavity — it is one
  `pocket_feature(...)` call that the engine cuts and the product's canvas edits
  afterwards; a cavity hand-built any other way has to be re-authored before the
  user can drag it. Not needed for a hole sized by a number rather than an object.
- **`outline`** — the product's short form of
  [references/outline.md](references/outline.md); read that file instead.

## Reference docs

Three areas have rules that don't fit here. **Read the file before you touch that
area** — each is short, and getting these wrong produces models the product can't
edit later.

| File | Read it before |
| --- | --- |
| [references/selectors.md](references/selectors.md) | Writing any persistent geometry reference — `selector.…` queries, `Body(features={…})`, mate sides |
| [references/assembly.md](references/assembly.md) | Poses, mates, joints, connectors, `Reference`/`MeshRef`, persistent appearance overrides, the `# <forgent3d:assembly>` managed block |
| [references/outline.md](references/outline.md) | Adding or editing a `#@` annotation — outline labels, sketch names, and knobs on a constant line (the parameters a visitor can turn) |

## Workflow

1. **Open with one concrete sentence** stating your approach. No generic
   acknowledgements.
2. **Edit** the source file. For a complex object, don't write it all in one
   draft: build the main form first, get it clean, then add the smaller features
   to a base that is known to build — a failure in a short draft names its own
   cause.
3. **`cad-build rebuild`.** Fix the first actionable error and rebuild until
   clean. Read the report against the request: sizes, bore positions, face
   offsets, every warning.
4. **`cad-build snapshot` and open the PNG.** Look before you measure: numbers
   confirm dimensions, but they don't catch a shape that's wrong in a way the
   report can't see — a bore on the wrong face, a feature mirrored, a fillet that
   didn't take. Only once the shape itself is right are measurements worth taking.
5. **`cad-build check --code '…'`** when a value decides your next edit and steps
   3–4 can't supply it — a boolean seam, a wall thickness, a tangency, an API you
   haven't used before. `print()` the measurement instead of guessing. Skip it
   otherwise; it leaves nothing behind either way.
6. **Before handing off**: if the model publishes `#@` knobs, `cad-build knobs`
   and fix anything `BROKEN` or `WARNS`. Then **`cad-build preview`** and
   hand the user the link; add `cad-build export` when they need the geometry
   itself rather than a link. Close with the defaults and forks you settled.

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
- The build report states geometry that contradicts correct source.
- `rebuild` and `preview` disagree.

This reaches the Forgent3D team through the same channel as the product's in-app
feedback widget; passing the source file lets them reproduce it. Keep the message
specific: what you did, what you expected, what happened. It's fire-and-forget —
send it, then continue or work around the issue. Don't block the user's task on it.

**Not feedback:** a build error caused by your own model — an illegal fillet, a
bad selector, a misplaced cutter — is yours to fix. The engine's error messages
name the fix for most dialect misses (a misspelt or unimported name, a method
that is a free function here); read them before assuming a gap. If changing the
source can make it right, it's not a tool bug.
