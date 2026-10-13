# The build123d route — model.py with cadkit

Read this when SKILL.md routed the request here: a parametric part or assembly in Forgent3D's
build123d dialect, measured by the kernel, editable in the product and exact in STEP. Everything
shared with the OpenSCAD route (commands, workflow, open decisions, bug reports) is in SKILL.md;
this file is what is specific to a `model.py`.

## Reading the rebuild report

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
- `spec-unbuilt` — a `# stated:` constant (a number the request gave) that nothing
  reads: that requirement is not built. Wire it into the feature it sizes.

The `spec` block holds every `# stated:` constant against the two face censuses,
through the value traces (which call each constant reached, and what the
argument came out as): a radius fed to `Cylinder` / `Circle` / `Hole` is looked
up in the cylinder census, a side or `extrude` amount fed to `Box` / `Rectangle` /
`extrude` is looked up as a pair of planar faces that far apart. Each line is a
fact: `found r4.5 Z ×2 @ x0 y0`, `NOT in the cylinder census`, `reaches no
geometry call — not built`, or `used by Pos@L14 (not a census dimension)`. A
stated value the solid does not show is a lead to **measure** (`check --code`
with `measure.cylinders` / `measure.span`), never to explain away: a later boolean
may have consumed it, or the cutter may have missed the part.

## check --code: a throwaway probe against the built model

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
- `measure.cylinders` reads trimmed and merged cylinders too (a hinge's
  teardrop-roofed bore, a helix-split tube) — as partial faces, listed with
  `include_partial=True`. It raises only when NONE of a solid's cylindrical
  faces could be read; faces it had to skip on an otherwise readable solid are
  counted in a `[measure] note:` line in the output, never dropped silently.
- `measure.walls` pairs two opposed faces only where their footprints overlap:
  a groove in a tube reads the wall behind it (1.2) and the full wall beside it
  (2.0), never the groove's own depth; two windows facing each other across a
  box are not a wall. It cannot tell a boss standing inside a bore of the same
  body from a tube (coaxial, nested faces) — that reads as a tube.
- `measure.walls(model)` — every material thickness it can prove (two opposed
  faces). Where a wall **wraps** a feature, check the derived surface exists
  instead (an R15 clearance in a 6 mm wall leaves an R21 face).
- `measure.slopes(model)` — ramp angles. `measure.interference(model)` — bodies
  sharing space. Every model-level reader measures each body in its **solved
  pose** (the managed block's mates applied, exactly where the rebuild placed
  it), so a check agrees with `body-interference`; a Body or Part passed on its
  own is read in its own frame. `measure.posed(model, "lid")` is one body in its
  solved pose, for reading it against a part or measuring a posed face.
- `measure.escape(lid, box, pull=(0, 0, 6), slack={"Y": (-0.8, 0.8)})` — does a
  latched part come free? Pulls `lid` off `box` along `pull` after letting it
  wander anywhere inside `slack` (its free play, mm per axis — a helper's
  `spec.play` / `spec.lateral_slop`). Prints FREE with the offset that escapes, or
  HELD. A snap or detent interferes when pulled straight, so a sweep along its
  one joint cannot tell a latch that holds from one that holds nothing; the
  failure is in the slack. Material thinner than 0.4 mm along the pull counts
  as slivers, not as holding.
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

## knobs: does every published control survive its range?

A `#@` knob is a promise to whoever opens the model's link: this slider runs
from here to there, this switch flips, each of these options builds. `knobs`
moves each one alone to its extremes — both ends of its range, the other switch
state, every dropdown option — and rebuilds. `BROKEN` means a visitor dragging
that control there gets a failed build; `WARNS` means the part still builds
there but degraded (a warning the default does not raise, or a body in pieces);
`INERT` means the control moves nothing. Run it before you hand off a model with
knobs: nothing else ever builds a value other than the default. Two knobs at
their extremes together are not built.

## preview publishes a shareable link

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

## export is fully local

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
  [outline.md](outline.md); read that file instead.

## Reference docs

Three areas have rules that don't fit here. **Read the file before you touch that
area** — each sits beside this one in `references/`, each is short, and getting
these wrong produces models the product can't edit later.

| File | Read it before |
| --- | --- |
| [selectors.md](selectors.md) | Writing any persistent geometry reference — `selector.…` queries, `Body(features={…})`, mate sides |
| [assembly.md](assembly.md) | Poses, mates, joints, connectors, `Reference`/`MeshRef`, persistent appearance overrides, the `# <forgent3d:assembly>` managed block |
| [outline.md](outline.md) | Adding or editing a `#@` annotation — outline labels, sketch names, and knobs on a constant line (the parameters a visitor can turn) |
