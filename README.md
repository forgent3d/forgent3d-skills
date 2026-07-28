# forgent3d-skills

Forgent3D's collection of [agent skills](https://github.com/vercel-labs/skills) —
portable instruction sets that teach a coding agent (Claude Code, Codex, Cursor,
Cline, Copilot, Windsurf, …) how to work with Forgent3D.

## Skills

- **[forgent3d-cad](skills/forgent3d-cad/)** — author / modify a Forgent3D CAD
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
```
npx skills update forgent3d/forgent3d-skills
```

Or point any agent at `skills/forgent3d-cad/SKILL.md` and run its tools with
`node skills/forgent3d-cad/bin/cad-build <cmd>`.

> These skills are maintained here, by hand. The only thing they depend on from
> Forgent3D is the `@forgent3d/cad-build` CLI they shell out to.
