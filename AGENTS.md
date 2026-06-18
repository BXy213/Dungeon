# Repository Instructions

<!-- project-context-maintainer:start -->
## Project Context Maintenance

This repository has opted into `$project-context-maintainer`.

These maintenance files are intentionally local and ignored by Git in this repository: `.codex/`, `AGENTS.md`, `docs/PROJECT_CONTEXT.md`, and `docs/PROJECT_SNAPSHOT.md`.

At the start of any Codex session in this repository, automatically bootstrap project understanding before answering architecture-sensitive questions or making changes. Do not wait for the user to ask for this.

Bootstrap sequence:

1. Read this `AGENTS.md`.
2. Read `.codex/project-maintenance.json`.
3. Read `docs/PROJECT_CONTEXT.md`.
4. Read `docs/PROJECT_SNAPSHOT.md`.
5. Use those docs as the project map, then inspect source files as needed for the task.

When modifying source, config, scenes, resources, build files, or project structure:

- Update `docs/PROJECT_CONTEXT.md` if behavior, architecture, workflows, module responsibilities, commands, or important constraints changed.
- Regenerate `docs/PROJECT_SNAPSHOT.md` with:

```bash
python "C:/Users/yangbo.ran/.codex/skills/project-context-maintainer/scripts/update_project_snapshot.py" --project .
```

- Optionally check for likely documentation omissions with:

```bash
python "C:/Users/yangbo.ran/.codex/skills/project-context-maintainer/scripts/check_project_docs.py" --project .
```

- In the final response, state whether project docs were updated or why no doc update was needed.
<!-- project-context-maintainer:end -->
