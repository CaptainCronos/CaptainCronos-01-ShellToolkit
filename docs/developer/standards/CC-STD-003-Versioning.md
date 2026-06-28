# CC-STD-003 — Versioning

Captain Cronos repositories use explicit version files and release tags.

---

## Version Source

The primary version file is:

```text
VERSION
```

Scripts should source `VERSION` or use shared library functions that read it.

---

## Version Fields

Common fields:

```bash
TOOLKIT_VERSION="1.0.0-alpha1"
TOOLKIT_CODENAME="Blackbeard"
STANDARDS_VERSION="0.1.0"
BASELINE_VERSION="ubuntu-26.04"
RELEASE_DATE="2026-06-28"
```

---

## Tags

Release tags use:

```text
vMAJOR.MINOR.PATCH
vMAJOR.MINOR.PATCH-alphaN
vMAJOR.MINOR.PATCH-betaN
vMAJOR.MINOR.PATCH-rcN
```

Example:

```text
v2.0.0-alpha
```

---

## Changelog Rule

Any version bump must update `CHANGELOG.md` before the tag is created.
