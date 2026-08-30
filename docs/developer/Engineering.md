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
ccvalidate release

Codex returns only when operator validation reports a failure requiring diagnosis.

Final repository completion:
ccvalidate finish

Interrupted post-merge continuation:
ccvalidate publish
```

This keeps broad mechanical validation local, reduces engineering-session
consumption, makes acceptance deterministic, removes repeated manual Git
completion steps, and preserves an explicit boundary around repository mutation.

Use `ccvalidate fast` for inexpensive development feedback. Bare `ccvalidate`
means `ccvalidate full`. Full mode runs the authoritative engineering selftest,
whose default suite includes the release gate, followed by the independent Git
diff check. Release mode delegates the release test out of that selftest run and
then invokes `cc release check` explicitly. Successful full and release runs
record separate Git-private PASS evidence for the exact clean repository and
HEAD. Release may reuse unchanged engineering evidence, but it always executes
its own release-readiness gate; full evidence alone never represents release
readiness.

Generated command references use the repository dispatcher and canonical
metadata under a fixed locale/color context. Help rendering bypasses
runtime-only dependency gates, ignores caller-specific program mappings and
shell startup hooks, and propagates generation failures instead of treating
partial help output as a stale committed document.

The `fast`, `full`, and `release` modes are validation-only. The explicit
`ccvalidate finish` mode owns the work-branch workflow: it requires the
ShellToolkit repository, an approved origin, a clean committed supported branch
(including `feature/*` and `release/*`), and fast-forward-only history. It may
reuse authoritative validation for the exact unchanged state before switching,
updates and merges main with `--ff-only`, records a local continuation marker
after the verified merge, and runs release validation.

Reusable validation evidence lives under `.git/ccvalidate/` with private
permissions and atomic updates. It binds the physical repository/Git-directory
identity, exact HEAD, clean tracked worktree, clean index, absence of untracked
files, and validation mode/result. A different commit, any dirty state, missing
or permissive state, malformed content, or an incomplete temporary file fails
closed and runs validation normally. A fast-forward to the already validated
commit may reuse its engineering PASS on main, while post-merge release and
publication readiness gates still run.

If that post-merge validation stops the workflow, repair and commit on local
main, then use `ccvalidate publish`. Publish never merges: it requires clean
main, the canonical origin, and a local main that is equal to or a strict
fast-forward descendant of `origin/main`. It refreshes the remote, runs the
authoritative release validation, refreshes again, stops if the remote changed,
pushes only `refs/heads/main:refs/heads/main`, and proves local main,
`origin/main`, and live remote main are identical. Only then may it delete the
marker-owned local work branch with `git branch -d`, and only when the branch
still has its recorded tip and Git proves it merged. Missing or invalid ownership
evidence produces a cleanup warning without guessing or deleting a branch.

Finish reuses the same publish, live-verification, and cleanup helpers. Neither
workflow stashes, resets, rebases, forces, rewrites history, resolves conflicts,
deletes remote work branches, or rolls back a failed operation. A failed push
or incomplete live verification preserves local main, the local work branch,
and continuation evidence for review. Repeating publish after success validates
and verifies the equal state without pushing again.

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
