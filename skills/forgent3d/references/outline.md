# Outline annotations (`#@` directives)

Read this before adding or editing any `#@` comment.

The marker has two hosts. On an **operation line** a `#@` directive labels that
operation in the readable outline and exposes selected call arguments as editable
UI fields. On a **constant definition line** it publishes that constant as a knob
— a parameter anyone who opens the model's link can turn (see
[Knobs](#knobs-on-a-constant-definition-line) below). Either way it is
**source-persisted UI metadata, not a second source of values**.

## Syntax

Place it at the end of the operation line, or on the line above:

```
#@ <label> <function_param>=<constant>
```

- Add `group=<id>` only to fold related operations under one heading.
- The first token containing `=` ends the label and starts the fields. Several
  fields may share one directive: `#@ Housing width=W depth=D height=H`.
- The key must be the **real call argument** — `amount`, `radius`, `width`,
  `height`.
- The value names which **leaf constant** the UI edits when that argument is an
  expression. It must be a leaf constant reachable from the expression — never
  the expression itself, never a computed intermediate such as `plate_h`, never
  an invented id. A non-leaf value is dropped and the field falls back to the
  picker.
- The value is a constant's **name, never a number**. Putting a value in the
  annotation would make it a second source of truth.
- A **tuple** argument takes a component suffix, `.x` / `.y` / `.z`, so each half
  names its own constant: `count=(COLS, ROWS)` is annotated
  `count.x=COLS count.y=ROWS`, `at=(PX, PY)` is `at.x=PX at.y=PY`. A tuple holds
  two constants under one argument name; without the suffix the binding cannot
  say which half it means.
- The directive is a comment and never executes. Missing or malformed metadata
  affects the outline label only, never geometry.

## When to annotate

Annotate only what the heuristics miss. A directly passed argument such as
`amount=STOCK` already exposes `STOCK`. Reach for `#@` when the editable driver
is buried in an expression, or when the operation needs a human label or grouping
it would not otherwise get.

## Examples

~~~python
STOCK = 8.0  # stock thickness
SKIN = 1.0   # skin thickness
plate = extrude(profile.sketch, amount=STOCK - 2 * SKIN)  #@ Plate amount=STOCK group=plate
~~~

`amount=STOCK` tells the UI to edit `STOCK` for the `amount` field; `SKIN` stays
part of the derived expression.

A loop body takes one directive for the whole repeated feature — bind the real
constant, not a derived half-value:

~~~python
for x, y in mount_positions:
    cover = safe_cut(cover, Cylinder(THROUGH_D / 2.0, depth), label="mount bore")  #@ Mount bores x6 radius=THROUGH_D
~~~

On a `with BuildSketch(...) as name:` line, the label is that sketch's **name** in
the model tree. The user can rename the sketch there, and the rename rewrites this
same comment — the name has no other storage. Keep any fields and `group=` on the
line when you relabel it.

~~~python
with BuildSketch(Plane.XY) as profile:  #@ Base outline
~~~

## Knobs (`#@` on a constant definition line)

The **same** marker on a module-level constant definition declares a public
knob — one field of this model's generator panel. The host decides what the keys
mean: on an operation line the pairs are `<param>=<constant>` bindings, on a
constant line they are the four reserved keys `range` / `step` / `choices` /
`group`. A helper parameter named `step` keeps reading as a binding.

The control is the `#@` comment on the constant's **own definition line, and
nothing else**. Never write a metadata dict, a schema, a `PUBLIC_PARAMS` table or
a `design_param` wrapper to describe one: that is a second source of truth and it
goes stale the first time someone edits the value.

~~~python
WALL  = 2.0     #@ Wall thickness (mm) range=1.2..4 step=0.2
COLS  = 3       #@ Columns range=1..8 step=1 group=size
LID   = True    #@ With lid
CELL_SIZES = {"small": 30.0, "medium": 40.0, "large": 55.0}
CELL  = "medium"                          #@ Cell size
pitch = CELL_SIZES[CELL]
CLEAR = 0.2     # no #@ — internal, not published
~~~

- The label is the text before the first `key=value`; a trailing `(mm)` is its
  unit. The four keys are `range=<min>..<max>`, `step=`, `choices=a,b,c` and
  `group=`. There is **no `type=`**: a number literal is a slider, `True`/`False`
  a switch, a string a dropdown or a text box. The type is a fact already written
  in the code; declaring it twice is a second source that rots.
- The constant must be a plain **literal** at its definition. `WALL = STOCK - 2 *
  CLEAR` cannot be a control — hoist the literal first. A `#@` on anything else is
  dropped, never wrapped in `design_param`.
- A dropdown's options come from the lookup **table** the constant indexes
  (`CELL_SIZES[CELL]` above), so there is nothing to keep in sync; `choices=` is
  only for a string with no such table. The option value **is** its display
  name — there is no label mapping, so write values a person can read. An
  `if`/`elif` chain is not read.
- Publish the few controls the request names, not every constant. Everything else
  stays a plain `#` comment and is still visible in the outline.
- Order is source order, and `group=` folds related controls under one heading.
- `group=` is the one key **both hosts** read. Write the same id on the knobs and
  on the operations they drive, and the parameter panel lists those steps under
  the knobs — the author's own statement of "this number moves that". Nothing is
  inferred, so an operation without the id is never linked:

  ~~~python
  CORNER_R  = 2.0   #@ Corner radius (mm) range=0..8 step=0.5 group=Pocket
  CLEARANCE = 0.5   #@ Clearance (mm) range=0.1..3 step=0.1 group=Pocket
  #@ Part pocket group=Pocket
  pocket_feature(tray, TOP, footprint=part.sketch, corner=CORNER_R, clearance=CLEARANCE, depth=7.0, id="part")
  ~~~
- `range=` is a claim you have to have tested: **build both ends before you write
  it.** An untested range ships green and breaks on the first visitor who drags
  the slider — nothing else in the pipeline ever exercises a value other than the
  default. `cad-build knobs` builds every knob at its extremes (range ends, the
  other switch state, every dropdown option): fix anything `BROKEN` (fails to
  build there) or `WARNS` (builds, but degraded — a pocket past the face, a
  capped fillet). A knob with no `range=` still gets a slider with a derived
  range, and `knobs` tests that one too.
- Prefer a slider to a dropdown. A number can be sampled; every dropdown option is
  a geometry branch, and options **multiply** — three dropdowns of four options
  each is 64 combinations to stand behind.
- Engraved text (a string knob feeding `Text()`) is limited to the bundled font:
  printable ASCII plus a few symbols, **no CJK**. Do not offer a text knob for
  lettering that has to be Chinese.
