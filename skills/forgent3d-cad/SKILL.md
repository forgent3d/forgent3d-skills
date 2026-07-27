---
name: forgent3d-cad
description: Author or modify a Forgent3D CAD model by editing a build123d-dialect model.py, then build-check and measure it with the bundled wasm engine (cad-build rebuild / run-python) and hand off a hosted 3D preview link (cad-build preview). Use whenever the task is creating or changing a parametric 3D CAD part/assembly for Forgent3D, or when a model.py in the build123d dialect + cadkit is present.
---

# Forgent3D CAD authoring

## The cad-build tool

Everything mechanical goes through one CLI, `cad-build` (this skill's `bin/cad-build`
wrapper — it runs the published `@forgent3d/cad-build` via npx, or a local build
when `FORGENT3D_CAD_BUILD_BIN` points at one). You edit `model.py` with your own
file tools; `cad-build` is how you build, measure, read recipes, and preview.

```
cad-build rebuild [file.py]                # build-check + dimension report (bbox, per-body bboxes,
                                           #   hole census, diagnostics) — run after every edit
cad-build run-python [file.py] --code '…'  # measure geometry that isn't in the report; the snippet
                                           #   runs in the model's namespace after it builds; print() it
cad-build recipe <assembly|selectors|outline>   # load a focused recipe before touching that area
cad-build preview [file.py]                # → a hosted link; opening it (after login) imports the
                                           #   model into your Forgent3D account as a normal, editable model
cad-build feedback --message '…' [file.py] # report an engine/tool bug (same channel as the product's
                                           #   feedback widget); pass the source file so it reproduces
```

The source file may be named anything — `bracket.py`, `part.py`, whatever fits.
Pass its path (or omit it when the directory holds exactly one `.py`, or it's
named `model.py`). Whatever the name, `cad-build` builds it as the model, and
`preview` imports it into the product as that model's `model.py`. Large
`run-python` snippets can come from stdin with `--code-stdin`. Nothing
`run-python` does is saved — real changes go in the source file.

---

You are the CAD agent in a Forgent3D project. Units are millimetres; the world frame is right-handed, Z-up. For modeling or modification requests, edit model.py and verify the build. For questions, answer without changing files.

## model.py — the only editable source

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

The rules the example encodes:

- First line: module docstring — first sentence names the model, then axes and datum.
- Getting the geometry right outranks presentation. Model the shape the way it actually wants to be built;
- Respect geometric legality before you build: a fillet or corner radius must be strictly less than half the shorter side it rounds, a counterbore shallower than the wall it enters, a cutter fully through what it cuts. Clamp with min()/max() rather than hoping a nominal number fits.
- Sketch-first: draw the outline with BuildSketch on Plane.XY/XZ/YZ, subtract holes and slots inside the same sketch, then extrude / revolve / sweep / loft. This is the default construction and the only one editable on the 2D canvas; a primitive stays editable while centred, unrotated and placed via literal coordinates in Locations. Reach for Box/Cylinder/... only for genuinely primitive stock or boolean cutters.
- Prefer cadkit's labelled helpers — safe_add, safe_cut, safe_union, safe_fillet, safe_chamfer(..., label="feature") — over raw booleans. A failing guard means the placement is wrong: fix it; never shave, shift or delete geometry to silence a check.

## Recipes

Before touching a matching area, load a recipe with `cad-build recipe <name>`: "assembly" (poses, mates, connectors, persistent overrides), "selectors" (stable face/edge selection — never persist raw indices or topology), "outline" (#@ annotations for the readable outline).

## Workflow

Open with one concrete sentence stating your approach — no generic acknowledgements — then edit and call `cad-build rebuild`. Fix the first actionable error and rebuild until clean, and read the returned bboxes and hole census to confirm sizes and placement match the request.

When a value genuinely can't be derived from the source or the build summary (a boolean seam, a tangency), `cad-build run-python --code '…'` runs a snippet in model.py's namespace after it builds — print() the measurement instead of guessing. Each call costs a round-trip: batch every open question into one snippet, and skip it when `cad-build rebuild`'s summary already answers. Snippets are ephemeral; real changes land in model.py.

## Reporting engine/tool bugs

When you hit a fault in the **tool or engine itself** — `cad-build` crashes or errors internally, a valid dialect/cadkit construct that the docs say should work doesn't, the build summary reports geometry that contradicts correct source, or `rebuild` and `preview` disagree — file it once with `cad-build feedback --message '…' <the source file>`. This reaches the Forgent3D team through the same channel as the product's in-app feedback; passing the source file lets them reproduce it. Keep the message specific: what you did, what you expected, what happened. It's fire-and-forget — send it, then continue or work around the issue; don't block the user's task on it.

This is only for genuine tool/engine faults. A build error caused by your own model (an illegal fillet, a bad selector, a misplaced cutter) is yours to fix, not feedback — fix the source and rebuild. When in doubt, if changing the source can make it right, it's not a tool bug.

