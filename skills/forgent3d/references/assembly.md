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
| `planar` | Face-on-face, anchored on the two faces' **centroids** unless a side ends in `.nearest(p)` (then p is the seat point). `Hinge`/`Slider` requires an explicit axis, because a plane does not define one. |
| `cylindrical` | Coaxial while preserving axial station — hinges and shafts. |
| `circular` | Coaxial and axially flush — rings and bore mouths. |
| `conical` | Aligns axes and seats apex-to-apex. |
| `point` | Records an anchored relationship without moving the body. |

### Flip, anchors and the 180° turn

- `flip=True` reverses the solver's default for **every** kind. Planar: opposed
  normals by default, aligned when flipped. Axial kinds: the default is whichever
  sign turns the move body **less** from its authored orientation, flipped is the
  other sign. A lid authored upright (skirt up, print orientation) that must seat
  upside down on a `circular` mate therefore needs `flip=True`; without it the
  solver keeps it upright and it lands through the box.
- A 180° turn has no shortest arc. The solver turns about **Y** for a ±Z mate
  direction (THREE's rule), which mirrors the move body in X; a hand-written
  `Rot(X=180)` mirrors it in Y. A symmetric lid cannot tell; an asymmetric one
  can (a chamfered-corner lid lands with its chamfer on the wrong corner, 85 mm³
  into the wall). The fix is **`spin=180` plus anchor points mirrored in y**:
  the Y-turn composed with a 180° spin about the mate direction is exactly
  `Rot(X=180)`, so the lid lands as the helper's `spec.seat` would put it
  (verified exact on the 10-10 chamfered snap-lid box). Swapping which +X / −X
  feature you pair only moves the translation, never the mirror. Or skip the
  mate and pose with `spec.seat`. For laying out features on a part the mate
  will turn over (clips on a lid), the Y-turn maps lid-local (x, y, z) to
  world (−x, y, −z) + the solved offset: a clip authored at lid x = +30 lands
  at world x = −30.
- A planar mate opposes the two faces' OUTWARD normals. A lid authored upright
  with its skirt / clips rising from the plate's top face therefore seats upside
  down on the rim with no `flip` at all — the mated face is the plate's top
  (where the skirt rises), not its underside.
- A planar or cylindrical side anchors on its entity's centroid. A rim ring
  with a notch (a cable slot, a finger scallop) has a centroid that drifted away
  from the notch, and a lid mated on it seats off-centre by that drift. Put
  `.nearest((x, y, z))` before the `.one()` / `.take(1)` that ends the side
  (on the Body feature or on the mate query — the mate's wins) to name the seat
  point. The point is used as given, projected onto the face's plane (or the
  cylinder's axis), so it need not lie on the face itself — the centre of a rim
  ring is fine. Or mate on a pair of circles (bore mouths, magnet pockets)
  instead. The rebuild's `connections` line prints the solved frame; the `@`
  point is the ref side's anchor.
- Connector geometry (`Pin`/`Peg`/`Dovetail`/`SnapPin`/`Ball` generated across a
  mate) exists only in the rebuild and the viewer: `check` measures the bodies
  WITHOUT it, so a connector's fit cannot be swept or measured there — use the
  source-side helper (`pin_and_bore`, `dovetail_pair`, …) when you need to
  verify the joint, and the connector when you only need it to exist. The
  `Dovetail` connector makes a rail and a groove of the same `length`, closed at
  both ends, centred on the mate point along the Slider's axis.
- `spin` defaults to the authored spin. A `thread_pair` cap mated `circular`
  onto its neck stays meshed because of that; `spin=90` unmeshes it (there is no
  helical joint).

### Motion

`Hinge(range=(min,max), axis=, pos=, drive="spin"|"hold"|"sweep", speed=)` uses
degrees. `drive` is the played preview motion: `"spin"` turns continuously,
`"sweep"` oscillates through `range`, `"hold"` keeps a pose with no motion of its
own. `speed` is deg/s (default 40).

`Slider(travel=(min,max), axis=, pos=)` uses millimetres and declares travel
freedom without a drive.

Axis/position are move-body local. Axial mates can derive them; otherwise declare
them. A derived hinge axis is the bore's direction, and `range=(0, 180)` is
signed by it — nothing knows which sense OPENS your lid. Read the axis off the
rebuild's `connections` line, probe one ±2° turn in a check
(`measure.interference(measure.posed(model, "lid").rotate(AXIS, 2), box)`), and
if the positive turn drives the lid into the box declare `Hinge(axis=(-1, 0, 0),
…)` so the viewer sweeps the right way. `measure.posed` (build123d.md) is the
starting pose for every sweep. A `Hinge` has no angle field: to snapshot an
open pose, rotate the authored lid geometry by a `#@` knob angle about the
hinge axis — the one case where posing a mate-driven body in the source is
the intended tool, and the cylindrical mate keeps whatever angle is authored.

For repeated holes or circular edges, give the Body a semantic feature ending in
`.all()` and pick per mate with
`selector.on("body").feature("name").nearest((x,y,z)).take(1)`. A mate side must
consume exactly one entity. Never copy face indices or fingerprints.

### Choosing connection geometry

| Intent | Geometry | Assembly declaration |
| --- | --- | --- |
| Rotation | `pin_and_bore` | cylindrical/circular mate + `Hinge` |
| Linear motion | `dovetail_pair` in the source, **or** the `Dovetail` connector (never both: the connector generates its own rail and groove) | mate + `Slider(axis=...)` — the connector's rail runs along the Slider's axis; without one its direction is the interface plane's default |
| Static location | `peg_socket` | mate without a motion joint, when persistence is useful |
| Printed retention | `snap_pin` | — |
| Posable joint | `ball_and_socket` | `Ball` connector, when generated across a mate |
| Screw cap / threaded joint | `thread_pair` | `circular` mate, `spin` at its default (keeps the helix meshed) |
| Lid on a box | `snap_lid_box` / `lip_lid_box` | planar mate, rim ↔ the plate face the skirt rises from, `.nearest` anchors on both (same y; asymmetric outline: add `spin=180`, anchors mirrored in y), or `spec.seat` by hand |
| Round snap cap | `snap_cap` | `circular` mate, cap's skirt-inner circle (`spec.skirt_inner_r` at z = lid_thickness) ↔ the jar's rim circle, `flip=True`; identical to `spec.seat` |

## After editing

Rebuild. Fix ambiguous / no-match selectors by improving feature intent, and fix
collision or fit errors in the geometry rather than changing the mate to hide
them. When a mate needs overlap, extend the mating dimension into its neighbour
and keep nominal outer faces where the design puts them; never shift a
dimensioned face just to manufacture overlap.
