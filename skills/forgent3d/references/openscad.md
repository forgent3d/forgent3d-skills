# The OpenSCAD route — a .scad rendered by OpenSCAD

Read this when SKILL.md routed the request here: the user works in OpenSCAD, or hands you a
`.scad`. `cad-build` runs the real OpenSCAD on the file (bundled as wasm, nothing to install) and
gives you what the desktop gives a person: the render, its size and the console. No model.py is
made and no B-rep kernel is involved; a STEP with exact surfaces comes from the preview link's
page. Everything shared with the build123d route (commands, workflow, open decisions, bug reports)
is in SKILL.md; this file is what is specific to a `.scad`.

There is no `check` on this route: nothing sits behind the render to probe. **`echo()` is your
probe** — print a derived dimension in the file and read it back in `rebuild`'s `echo:` lines.

## The project is the folder

The `.scad` you name is the entry; **its folder is the project**. Every `.scad`
in it is mounted at its relative path, so `include <lib/bearing.scad>` and
`use <config.scad>` resolve as on the desktop (relative to the file that names
them), and so does every data file OpenSCAD reads: `import("part.stl")`,
`surface("height.png")`, `use <font.ttf>`. `--root <dir>` mounts a larger
folder when the entry sits below the files it includes. MCAD, BOSL2 and
Write.scad are built in; any other library goes into the folder.

A missing include is a hard error here, on purpose: OpenSCAD only warns and
renders the rest, which silently drops a part of the model.

## Reading the report

The report is OpenSCAD's own render read back — the same mesh F5 shows:

- **`bbox: size [w x d x h] min [x, y, z]`** — the model's extent and where it
  sits. The first thing to check against the request: a part that should be
  40 wide and reads 44 has a wall counted twice.
- **`volume`** — of the facets, so a cylinder at the default `$fn` reads a few
  percent under the true value. Good for "did the hole get cut" and "did the
  rib get added", not for a tolerance.
- **`render: N triangles in M mesh(es)`** — `%` background meshes are listed
  apart and are not part of the model; a 2D model says so.
- **`echo:`** — every `echo()` the file printed, in order. Put the numbers you
  derive (`echo("inner", inner_d)`) in the file; this is how you measure.
- **`warnings`** — OpenSCAD's own words at the `.scad` line: an undefined
  variable, a deprecated form, a shape it dropped. Treat as in the desktop
  console. One line stands for all warnings inside a bundled library.
- **`empty: Current top level object is empty`** is OpenSCAD's own message: every
  object came out with no volume (a size left at 0, a `difference()` that ate
  everything). It is not an error, but nothing can be exported from it.

What the report cannot tell you: where a hole is, whether two features
intersect, whether a wall is the thickness you meant. **Look**: `snapshot`.

## Customizer parameters are the knobs

A top-level `name = <literal>;` above the first module is a parameter OpenSCAD
itself recognises — and what a visitor of the preview link can turn:

```
wall = 2;             // [1:0.2:4]      ← slider
style = "round";      // [round, square] ← dropdown
lid = true;                              ← switch
```

The comment line above an assignment is its caption. Keep parameters as
literals: an expression, or anything after the first `module`, is not one.
`cad-build knobs` moves each one alone to its extremes and re-renders: `BROKEN`
means OpenSCAD errors there or the render comes out empty; `WARNS` means it
renders but with a warning the default does not raise; `INERT` means the
parameter moves nothing. Run it before handing off a model with parameters,
and fix or narrow what breaks. Values are written back into the source and
re-rendered, exactly as the page's panel does — nothing goes through `-D`.

## snapshot: look before you trust

With no flags, `snapshot` renders the 2×2 third-angle sheet (TOP, ISO, FRONT,
RIGHT SIDE, one scale and centre). `--view top|front|right|left|back|bottom|iso`
renders one view alone. A shaded render only draws **visible** outlines — never
conclude a hole is missing from one; `--line-art --xray` dashes the hidden
edges, the way a drawing does. `color()` in the file shows in the snapshot.

## export is OpenSCAD's mesh; STEP is the page's

`export` writes OpenSCAD's own triangles — the same STL the desktop's F6 → Export
gives — as `stl`, `3mf`, `glb` or `obj`, fully locally. A mesh has no exact
surfaces, so there is no STEP here: when the user needs STEP (a machine shop, a
CAD tool), hand them the `preview` link — the page behind it converts the file
with true cylinders and spheres and exports STEP. Say that in your reply rather
than apologising for the format.

## preview publishes a link that carries the code

`preview` puts the file itself into the link (`…/scad#code=…`): whoever opens it
sees the real OpenSCAD render it in their browser, can turn the Customizer
parameters and export STL or STEP — without signing in, and **nothing is
uploaded or stored**. Because the link *is* the code, re-run `preview` after an
edit for a fresh one, and send the user the latest. One link holds one file: a
project that includes other files is refused a link and should be shared as a
folder (the page loads one), or as an STL from `export`.

## Workflow notes for this route

Step 3 of the shared workflow is `cad-build rebuild part.scad`: read bbox, volume and your
`echo()` lines against the request, and every warning. Step 5 does not exist here — look
(`snapshot`) instead of probing. Before handing off: `knobs` if the file publishes Customizer
parameters, then `preview` (STEP lives on that page) and `export --format stl` (or `3mf`)
when the user is printing it.

## Modeling rules

- **First line is a comment naming the part.**
- **Parameters at the top**, as literals with Customizer annotations, every
  dimension the request states among them. Derive the rest from those names;
  never repeat a magic number. `echo()` the derived ones you need to check.
- **Cut through, not to**: a hole's cutter starts below the face and ends above
  it (`translate([x, y, -1]) cylinder(h = t + 2, …)`), so faces never coincide —
  coincident faces leave zero-thickness skins in the render.
- **A stated wall is a difference of the outer shape and its inset**, derived
  from the same parameters — not two independently sized solids.
- **Respect legality before you render**: a rounding smaller than half the
  shorter edge, a counterbore shallower than the wall it enters. Clamp with
  `min()` / `max()`, or `assert()` what must hold — the render stops at the
  assertion and names its line.
- **`$fn` is appearance**: leave it alone unless you mean a polygon (`$fn = 6`
  for a hex socket). The STEP the page produces is exact whatever `$fn` says,
  and a high `$fn` only slows the render.
- **Positions over parts**: when two pieces must fit, derive both from one set
  of parameters and leave clearance; touching is fine, shared volume merges them
  into one in the render — read the snapshot.

## Not this route

Fillets by edge selection, shells, selectors, assemblies with mates, parts the product's canvas
edits and a measured B-rep are the build123d route (`references/build123d.md`). Don't write a
model.py here.
