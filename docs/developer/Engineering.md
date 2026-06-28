# Engineering Overview

Captain Cronos Shell Toolkit follows a documentation-first engineering workflow.

```text
Plan -> Document -> Implement -> Verify -> Release
```

The repository should remain rebuildable, auditable, and recoverable from source control.

---

## Engineering Principles

- Keep the toolkit simple enough to debug from a rescue shell.
- Prefer documented standards over one-off fixes.
- Separate source, defaults, baselines, backups, and migrations.
- Preserve a rollback path before installing or updating user shell files.
- Treat Git history as the source of truth.
- Do not allow installer behavior to create untracked or modified repository files.
- Keep public commands stable.

---

## Public Interface

The public interface should remain small:

```text
cc
helpme
gitflow
```

Most new functionality should be accessed through `cc` subcommands rather than creating more top-level commands.

---

## Development Rules

1. Update documentation before or alongside feature work.
2. Add or update standards when a new pattern becomes permanent.
3. Run verification before committing.
4. Keep migrations in `archive/migrations/` after use.
5. Avoid changing top-level repository layout without updating the roadmap.
6. Keep `VERSION`, `CHANGELOG.md`, and `ROADMAP.md` aligned.

---

## Verification Expectations

Before a release or major pull point:

```bash
install/verify.sh
cc doctor
bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions
```

The repository should be clean after install, update, and verification.

---

## Milestone Rule

Feature work may pause when architecture, installer behavior, versioning, or documentation falls behind implementation.

Milestone M2 exists specifically to prevent technical debt before the toolkit expands further.
