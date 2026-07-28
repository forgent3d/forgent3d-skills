# Outline annotations (`#@` directives)

Read this before adding or editing any `#@` comment.

A `#@` directive labels an operation in the readable outline and exposes selected
call arguments as editable UI fields. It is **source-persisted UI metadata, not a
second source of values**.

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
