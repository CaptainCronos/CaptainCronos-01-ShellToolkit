# CC-STD-002 — Repository Layout

The Engineering Manual's `07-Standards/Directory-Structure.md` governs
ecosystem-wide directory policy. ShellToolkit's implemented layout and path
responsibilities are defined in [`../Repository-Layout.md`](../Repository-Layout.md).

This page records only the subset consumed by ShellToolkit tooling.

## Toolkit Inputs

```text
VERSION
manifest.yml
```

Release and generated-document checks also consume `README.md`, `ROADMAP.md`,
and `CHANGELOG.md`; those files are project artifacts, not a required template
for every Captain Cronos repository.

## Toolkit Paths

```text
archive/
assets/
config/
docs/
examples/
install/
lib/
plugins/
releases/
templates/
tests/
tools/
bash/
baseline/
defaults/
```

The complete purpose of each path and the approval rule for new top-level paths
are maintained in [`../Repository-Layout.md`](../Repository-Layout.md).

---

## Repository Cleanliness

Normal ShellToolkit installation, update, verification, and doctor commands
must not modify tracked repository files or tracked file modes.
