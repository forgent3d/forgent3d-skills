---
name: openscad
description: Author or modify an OpenSCAD model (.scad) with Forgent3D's cad-build CLI, which bundles the real OpenSCAD — nothing to install. Render it and read the result back (cad-build rebuild: bbox, volume, triangle count, what the file echo()ed), see it in orthographic views (cad-build snapshot), walk its Customizer parameters (cad-build knobs), export STL/3MF/GLB/OBJ for printing (cad-build export) and hand off a shareable link that carries the code and converts it to STEP (cad-build preview). Use whenever the task is creating or changing a 3D part in OpenSCAD, or a .scad file is present.
---

# OpenSCAD authoring with Forgent3D

You write OpenSCAD — the language you already know, every module, loop,
`include`/`use`, MCAD, BOSL2 and Write.scad included. `cad-build` runs the real
OpenSCAD on your file (bundled as wasm, so there is nothing to install), and
gives you what the desktop gives a person: the render, its size, and the
console. Units are millimetres, Z-up, as in OpenSCAD.

- **Modeling or modification request** → edit the `.scad`, then render and look.
- **Question** → answer it; change no files.

You edit the source with your own file tools. Everything else — render,
measure, look, export, publish, report bugs — goes through one CLI: `cad-build`.

## Commands

`cad-build` is this skill's `bin/cad-build` wrapper — **not on PATH**, call it
by path: `<this skill's directory>/bin/cad-build`. It runs the published
`@forgent3d/cad-build` via npx (OpenSCAD ships inside it), or a local build
when `FORGENT3D_CAD_BUILD_BIN` points at one.

```
cad-build rebuild    part.scad                              # OpenSCAD renders → bbox, volume, triangles, echo()
cad-build snapshot   part.scad [--view front] [--line-art] [--xray]   # orthographic PNG of the render
cad-build knobs      part.scad                              # every Customizer parameter rendered at its extremes
cad-build export     part.scad --format stl                 # stl | 3mf | glb | obj — OpenSCAD's own triangles
cad-build preview    part.scad                              # → shareable link that carries the code (STEP there)
cad-build feedback --message '…' part.scad                  # report an engine/tool bug
```

| Command | Returns | When |
| --- | --- | --- |
| `rebuild` | `ok`, bbox (size and min corner), volume (mm³), triangle count, the file's `echo()` lines, OpenSCAD's warnings at their `.scad` lines — or OpenSCAD's error, at its line | After **every** edit |
| `snapshot` | path to a PNG: the 2×2 sheet (top / iso / front / right), or one `--view` | Once it renders clean — to *see* it before you trust it |
| `knobs` | every Customizer parameter rendered at its extremes: `OK` / `INERT` / `WARNS` / `BROKEN` | Before handing off a model with parameters |
| `export` | path to the written file, next to the source unless `--out` says otherwise | The user wants the part itself: STL or 3MF for a printer, GLB for a viewer |
| `preview` | a link anyone can open: OpenSCAD renders the code there, parameters live, STEP and STL export | When the model is done and verified, and whenever STEP is wanted |
| `feedback` | nothing (fire-and-forget) | A fault in the tool itself |

There is no `check` for a `.scad`: nothing sits behind the render to probe.
**`echo()` is your probe** — print a derived dimension in the file and read it
back in `rebuild`'s `echo:` lines.

### The project is the folder

The `.scad` you name is the entry; **its folder is the project**. Every `.scad`
in it is mounted at its relative path, so `include <lib/bearing.scad>` and
`use <config.scad>` resolve as on the desktop (relative to the file that names
them), and so does every data file OpenSCAD reads: `import("part.stl")`,
`surface("height.png")`, `use <font.ttf>`. `--root <dir>` mounts a larger
folder when the entry sits below the files it includes. MCAD, BOSL2 and
Write.scad are built in; any other library goes into the folder.

A missing include is a hard error here, on purpose: OpenSCAD only warns and
renders the rest, which silently drops a part of the model.

### Reading the report

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

### Customizer parameters are the knobs

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

### snapshot: look before you trust

With no flags, `snapshot` renders the 2×2 third-angle sheet (TOP, ISO, FRONT,
RIGHT SIDE, one scale and centre). `--view top|front|right|left|back|bottom|iso`
renders one view alone. A shaded render only draws **visible** outlines — never
conclude a hole is missing from one; `--line-art --xray` dashes the hidden
edges, the way a drawing does. `color()` in the file shows in the snapshot.

### export is OpenSCAD's mesh; STEP is the page's

`export` writes OpenSCAD's own triangles — the same STL the desktop's F6 → Export
gives — as `stl`, `3mf`, `glb` or `obj`, fully locally. A mesh has no exact
surfaces, so there is no STEP here: when the user needs STEP (a machine shop, a
CAD tool), hand them the `preview` link — the page behind it converts the file
with true cylinders and spheres and exports STEP. Say that in your reply rather
than apologising for the format.

### preview publishes a link that carries the code

`preview` puts the file itself into the link (`…/scad#code=…`): whoever opens it
sees the real OpenSCAD render it in their browser, can turn the Customizer
parameters and export STL or STEP — without signing in, and **nothing is
uploaded or stored**. Because the link *is* the code, re-run `preview` after an
edit for a fresh one, and send the user the latest. One link holds one file: a
project that includes other files is refused a link and should be shared as a
folder (the page loads one), or as an STL from `export`.

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

## When the request leaves a decision open

A choice the request leaves open is yours to settle: derive it, measure it, or
take the reasonable default and **render**. Don't stop to confirm a plan you
have already settled on — a part the user can look at beats a question.

Owe it back in the reply, one line each, in the user's own terms: each
**number** you defaulted ("wall 2 mm", "corners R3") — and make it a parameter
at the top of the file — and each **fork** you settled, with the other branch
beside it. Two forks must never go unmentioned: the size of what the part must
**fit** when nothing fixes it, and a fork whose branches are different parts.

## Workflow

1. **Open with one concrete sentence** stating your approach.
2. **Edit** the `.scad`. For a complex object, get the main form rendering clean
   first, then add features to a base known to render.
3. **`cad-build rebuild`.** Fix the first error (it names the `.scad` line) and
   re-run until clean. Read bbox, volume and your `echo()` lines against the
   request; read every warning.
4. **`cad-build snapshot` and open the PNG.** The bbox cannot see a feature on
   the wrong face or mirrored; the picture can.
5. **Before handing off**: `cad-build knobs` if the file publishes parameters and
   fix anything `BROKEN` or `WARNS`. Then `cad-build preview` and hand the user
   the link (STEP lives there); `cad-build export --format stl` (or `3mf`) when
   they are printing it. Close with the defaults and forks you settled.

## Reporting tool bugs

File once with `cad-build feedback --message '…' part.scad` when you hit a fault
in the **tool itself**:

- `cad-build` crashes or errors internally.
- A `.scad` that desktop OpenSCAD renders fine is rejected here, or renders
  differently (a volume or a size the desktop disagrees with).
- `rebuild` and the preview page disagree.

Passing the file lets the team reproduce it. Keep the message specific: what you
did, what you expected, what happened. Fire-and-forget — send it, then continue
or work around it; don't block the user's task on it. Update first when a fix
may already have shipped:

```
npx skills update openscad                 # this skill
npx -y @forgent3d/cad-build@latest help    # refresh the CLI npx cache
```

**Not feedback:** an OpenSCAD error in your own code (an undefined variable, an
assertion you wrote, a missing include) is yours to fix — the message names the
line. If changing the `.scad` can make it right, it's not a tool bug.

## Not this skill

The Forgent3D dialect (`model.py`, build123d + cadkit: measured B-rep, fillets
by edge selection, shells, selectors, assemblies with mates, parts the product's
canvas edits) is the **forgent3d** skill. Don't write a model.py here.
