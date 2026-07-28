# Assembly state

Read this before adding or editing poses, mates, joints, connectors, references
or persistent appearance overrides.

## The managed block

The global `model` is always required. The global `assembly` and its managed
block are **optional**. Multiple Bodies may be published without assembly state;
do not add an empty block merely to make the file build.

Create assembly state only when the design needs a mate, joint, connector,
persistent rest transform, user/editor appearance override, `Reference`, or
`MeshRef`. When used, keep exactly one complete managed block at the end of the
source file:

~~~python
# <forgent3d:assembly>
# Assembly state — shared by AI and the Forgent3D assembly editor.
# Managed block: the editor rewrites only this block on every save.
from cadkit import Assembly, Hinge, Pin, mate, selector

assembly = Assembly(model=model, connections=[
    mate(
        id="conn-arm",
        move=selector.on("arm").feature("pivot").one(),
        ref=selector.on("base").feature("pivot").one(),
        kind="cylindrical",
        joint=Hinge(range=(-20, 110), drive="sweep", speed=30),
        connector=Pin(diameter=4, fit="running"),
    ),
])
# </forgent3d:assembly>
~~~

The managed block owns every persistent pose override, user appearance override,
`Reference`, `MeshRef`, mate, joint and connector. The editor may normalize
everything inside it. Never write partial or duplicate marker pairs, and do not
put `assembly = Assembly(...)` outside the markers.

The user co-edits this state in the 3D editor. If the latest user turn includes
current assembly state, it is authoritative and supersedes every earlier copy in
the conversation — preserve its accumulated transforms, appearance overrides,
references and connections exactly when editing unrelated geometry, unless the
request changes them. If a write is rejected because the source changed, read it
again and reapply the edit to the new version.

## Let the solver place things

Build each mate-driven rigid `Body.geometry` in a convenient body-local frame.
Name stable body-local semantic features with deferred selector queries, then
relate bodies declaratively with `mate(...)`. Let the constraint solver compute
world poses:

- Do **not** derive assembled translations from bounding boxes.
- Do **not** bake world placement into mate-driven `Body.geometry` with
  `Pos`/`Location`.
- Do **not** add a `Transform` to a mate-driven body. `Transform` is only for an
  intentionally unconstrained free-standing body or reference whose absolute pose
  is user-authored.
- Remove redundant transforms reported by `mate-overrides-rest`.

Every mate declares which Body moves and which is the fixed reference. Both sides
must be bound selector queries ending in `.one()` or `.take(1)`. Use stable
connection ids. See [selectors.md](selectors.md) before authoring or repairing
persistent feature queries.

Put designed default color/material in `Body(appearance=Appearance(...))`;
`Assembly.appearance` is only for user/editor overrides. Declare live references
in the managed block with `Reference(model="...")` or `MeshRef(file="imports/...")`;
never edit mounted `refs/` files or copy their geometry into the local model.

## Joints, connectors and mating geometry

Treat geometry and assembly intent as two coordinated layers:

1. The source file creates the real mating geometry. Cadkit helpers
   `pin_and_bore`, `peg_socket`, `dovetail_pair`, `snap_pin` and
   `ball_and_socket` are geometry generators.
2. The managed assembly block declares the semantic relationship with `mate(...)`,
   its `Hinge`/`Slider` motion, and any `Pin`/`Peg`/`Dovetail`/`SnapPin`/`Ball`
   connector.

Publish stable semantic features such as `"pivot"` on each finished rigid Body
before binding them from the managed block, as in the example above.

### Mate kinds

| Kind | Meaning |
| --- | --- |
| `planar` | Face-on-face. `Hinge`/`Slider` requires an explicit axis, because a plane does not define one. |
| `cylindrical` | Coaxial while preserving axial station — hinges and shafts. |
| `circular` | Coaxial and axially flush — rings and bore mouths. |
| `conical` | Aligns axes and seats apex-to-apex. |
| `point` | Records an anchored relationship without moving the body. |

### Motion

`Hinge(range=(min,max), axis=, pos=, drive="spin"|"hold"|"sweep", speed=)` uses
degrees. `drive` is the played preview motion: `"spin"` turns continuously,
`"sweep"` oscillates through `range`, `"hold"` keeps a pose with no motion of its
own. `speed` is deg/s (default 40).

`Slider(travel=(min,max), axis=, pos=)` uses millimetres and declares travel
freedom without a drive.

Axis/position are move-body local. Axial mates can derive them; otherwise declare
them.

For repeated holes or circular edges, give the Body a semantic feature ending in
`.all()` and pick per mate with
`selector.on("body").feature("name").nearest((x,y,z)).take(1)`. A mate side must
consume exactly one entity. Never copy face indices or fingerprints.

### Choosing connection geometry

| Intent | Geometry | Assembly declaration |
| --- | --- | --- |
| Rotation | `pin_and_bore` | cylindrical/circular mate + `Hinge` |
| Linear motion | `dovetail_pair` | planar/cylindrical mate + `Slider` |
| Static location | `peg_socket` | mate without a motion joint, when persistence is useful |
| Printed retention | `snap_pin` | — |
| Posable joint | `ball_and_socket` | `Ball` connector, when generated across a mate |

## After editing

Rebuild. Fix ambiguous / no-match selectors by improving feature intent, and fix
collision or fit errors in the geometry rather than changing the mate to hide
them. When a mate needs overlap, extend the mating dimension into its neighbour
and keep nominal outer faces where the design puts them; never shift a
dimensioned face just to manufacture overlap.

For stylized or reference models, prefer the overall envelope and a few signature
proportions over one parameter per visible feature.
