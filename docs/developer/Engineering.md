# Engineering Overview

Captain Cronos Shell Toolkit follows a documentation-first engineering workflow.

The Engineering Manual governs ecosystem-wide development, Git, documentation,
and release policy. This page adds ShellToolkit-specific engineering guidance.

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
2. Add or update a local implementation contract when a ShellToolkit pattern
   becomes permanent; update ecosystem policy only in the Engineering Manual.
3. Run verification before committing.
4. Keep migrations in `archive/migrations/` after use.
5. Avoid changing top-level repository layout without updating the roadmap.
6. Keep `VERSION`, `CHANGELOG.md`, and `ROADMAP.md` aligned.

---

## Verification Expectations

Captain Cronos development uses a deliberate implementation/acceptance split:

```text
Codex:
architecture + implementation + focused tests + changed-file checks + diff review

Operator:
ccvalidate full

Codex returns only when operator validation reports a failure requiring diagnosis.

Final repository completion:
ccvalidate finish
```

This keeps broad mechanical validation local, reduces engineering-session
consumption, makes acceptance deterministic, removes repeated manual Git
completion steps, and preserves an explicit boundary around repository mutation.

Use `ccvalidate fast` for inexpensive development feedback. Bare `ccvalidate`
means `ccvalidate full`. Full mode runs the authoritative engineering selftest,
whose default suite includes the release gate, followed by the independent Git
diff check. Release mode delegates the release test out of that selftest run and
then invokes `cc release check` explicitly, so the same broad coverage and final
release gate execute without running identical expensive checks twice.

Generated command references use the repository dispatcher and canonical
metadata under a fixed locale/color context. Help rendering bypasses
runtime-only dependency gates, ignores caller-specific program mappings and
shell startup hooks, and propagates generation failures instead of treating
partial help output as a stale committed document.

The `fast`, `full`, and `release` modes are validation-only. Only the explicit
`ccvalidate finish` mode may change Git state. It requires the ShellToolkit
repository, an approved origin, a clean committed feature/fix/development
branch, and fast-forward-only history. It validates before switching branches,
updates and merges main with `--ff-only`, revalidates before pushing only
`main -> origin/main`, verifies the remote commit, and then uses safe local
branch deletion. It never stashes, resets, forces, rewrites history, resolves
conflicts, or deletes a feature branch after a failed step.

The function is maintained in `bash/bash_functions` and promoted verbatim to
`defaults/v1/bash_functions`; installer and update workflows deploy that
canonical source. Do not hand-edit only `~/.bash_functions`.

Before a release or major pull point, the local operator runs:

```bash
ccvalidate full
```

The repository should be clean after install, update, and verification.

---

## Milestone Rule

Feature work may pause when architecture, installer behavior, versioning, or documentation falls behind implementation.

Milestone M2 exists specifically to prevent technical debt before the toolkit expands further.
