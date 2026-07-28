# forgent3d-skills

Forgent3D's collection of [agent skills](https://github.com/vercel-labs/skills) —
portable instruction sets that teach a coding agent (Claude Code, Codex, Cursor,
Cline, Copilot, Windsurf, …) how to work with Forgent3D.

## Skills

- **[forgent3d](skills/forgent3d/)** — author / modify a Forgent3D CAD
  model.py: edit the build123d dialect, build-check + measure it with the bundled
  wasm engine, and hand off a hosted 3D preview link.

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
