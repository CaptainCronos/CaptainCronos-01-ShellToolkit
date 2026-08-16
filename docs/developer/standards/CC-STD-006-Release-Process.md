# CC-STD-006 — Release Process

The Engineering Manual's `02-Git/Release-Workflow.md` is authoritative for the
ecosystem release procedure, and `07-Standards/Versioning.md` governs version
and tag formats. This page adds ShellToolkit's project-specific release gates.

---

## Release Requirements

Before tagging a release:

- `README.md` is current.
- `ROADMAP.md` is current.
- `CHANGELOG.md` is current.
- `VERSION` is correct.
- `manifest.yml` is reviewed.
- Installer dry-run succeeds.
- Installer verification succeeds.
- `cc doctor` succeeds or warnings are documented.
- Repository working tree is clean.

---

These checks supplement rather than replace the Manual's validation, review,
commit, tagging, and publication steps. The maintained operational checklist is
[`../Release-Checklist.md`](../Release-Checklist.md).
