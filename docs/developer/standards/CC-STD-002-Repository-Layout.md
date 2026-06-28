# CC-STD-002 — Repository Layout

Captain Cronos repositories should use a predictable layout so installers, documentation, verification tools, and future automation can be reused.

---

## Required Core Files

```text
README.md
ROADMAP.md
CHANGELOG.md
VERSION
manifest.yml
LICENSE
```

---

## Standard Directories

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
```

Shell Toolkit also includes:

```text
bash/
baseline/
defaults/
```

---

## Rule

Do not create new top-level directories casually. New top-level directories require documentation and roadmap approval.

---

## Repository Cleanliness

Normal installation, update, verification, and doctor commands must not modify tracked repository files or tracked file modes.
