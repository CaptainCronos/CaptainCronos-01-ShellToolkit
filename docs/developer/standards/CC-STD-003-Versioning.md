# CC-STD-003 — Versioning

The Engineering Manual's `07-Standards/Versioning.md` governs ecosystem version
identifiers and tags. This document defines the version representation consumed
by ShellToolkit.

---

## Version Source

The ShellToolkit version source is:

```text
VERSION
```

ShellToolkit commands should use shared version helpers that read `VERSION`
rather than duplicating the toolkit version.

---

## Version Fields

Current ShellToolkit fields:

```bash
TOOLKIT_VERSION="1.0.0-alpha1"
TOOLKIT_CODENAME="Blackbeard"
STANDARDS_VERSION="0.1.0"
BASELINE_VERSION="ubuntu-26.04"
RELEASE_DATE="2026-06-28"
```

---

`TOOLKIT_VERSION` is the released toolkit identifier. The other fields are
ShellToolkit metadata and do not establish a second ecosystem standards
authority. Tag shape and the `CHANGELOG.md` update rule come from the
Engineering Manual; local release validation is described in
[`CC-STD-006-Release-Process.md`](CC-STD-006-Release-Process.md).
