# forgent3d-skills

Forgent3D's collection of [agent skills](https://github.com/vercel-labs/skills) —
portable instruction sets that teach a coding agent (Claude Code, Codex, Cursor,
Cline, Copilot, Windsurf, …) how to work with Forgent3D.

## Skills

- **[forgent3d](skills/forgent3d/)** — author / modify a 3D CAD part with Forgent3D.
  One skill, two routes it picks from the request: a build123d-dialect `model.py`
  (built and measured on the bundled wasm engine, exported to STEP, hosted as an
  editable 3D link) or an OpenSCAD `.scad` (rendered by the bundled OpenSCAD, read
  back, exported to STL/3MF, handed off as a link that carries the code and
  converts it to STEP). Nothing to install either way.

## Install

Uses the `skills` convention (`skills/<name>/SKILL.md`), so any `skills`-aware
agent can install directly:

```
# the whole collection
npx skills add forgent3d/forgent3d-skills
```

## Update

`update` takes the **installed skill name**, not the repo slug, and acts on the
directory you run it in (add `-g` if you installed globally):

```
npx skills list              # what's installed, and where
npx skills update forgent3d
```

Or point any agent at `skills/forgent3d/SKILL.md` and run its tools with
`node skills/forgent3d/bin/cad-build <cmd>`.

> These skills are maintained here, by hand. The only thing they depend on from
> Forgent3D is the `@forgent3d/cad-build` CLI they shell out to.
