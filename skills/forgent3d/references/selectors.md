# Persistent selectors

Read this before authoring or repairing any persistent geometry reference.

Persistent geometry references are composable selector queries resolved
body-locally at build time.

- Start with `selector.faces()`, `selector.edges()`, or `selector.feature("name")`.
- Inside `Body(features={...})`, keep the query unbound: `selector.faces()…`.
- In the managed assembly block, bind it to a Body with `selector.on("body")…`.
- Filter with `.where(Q.…)` — `Q.normal("+z")`, `Q.axis("z")`, `Q.surface("cylinder")`,
  `Q.curve("circle")`, `Q.radius(3)`, `Q.area(min=)`, `Q.length(max=)`,
  `Q.center("z", 16)` (±0.001 mm unless `tolerance=` is given), `Q.distance((x,y,z), max=)`, `Q.internal()`,
  `Q.external()`, or `Q.all` / `Q.any` / `Q.not_`.
- Rank with `.extreme(By.center("+z"), "max")`, `.order_by(By.area().desc())`, or
  `.nearest((x,y,z))`. Ranking only orders or narrows candidates; it does not
  consume them.
- Finish every query explicitly with `.one()`, `.all()`, or `.take(n)`. Use
  `.nearest(point).take(1)` when choosing the closest member is intentional.

`Q.normal("+z")` means "faces upward", not "the top face". Add
`.extreme(By.center("+z"), "max")` for the highest upward face.

Mate `move` / `ref` sides must resolve exactly one entity with `.one()` or
`.take(1)`. For repeated holes or edges, store the group as a semantic Body
feature ending in `.all()`, then choose one per mate with
`selector.on("body").feature("holes").nearest(point).take(1)`.

## Never

Never persist face indices, resolved `Face`/`Edge` objects, centroids,
fingerprints, or guessed topology. If `.one()` is not unique, improve the
geometric intent with filters, an extreme, a deliberate nearest/take, or a named
semantic feature — never weaken the resolver.
