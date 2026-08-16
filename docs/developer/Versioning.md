# Versioning

Captain Cronos Shell Toolkit uses explicit version files and release labels to keep the toolkit auditable.

The Engineering Manual's `07-Standards/Versioning.md` governs ecosystem-wide
version and tag policy. This page defines ShellToolkit's repository-local
version data and how its commands consume it.

---

## Source of Truth

The repository-level version source is:

```text
VERSION
```

Scripts should read runtime toolkit version data from this file instead of hardcoding toolkit versions.

Example fields:

```bash
TOOLKIT_VERSION="1.0.0-alpha1"
TOOLKIT_CODENAME="Blackbeard"
STANDARDS_VERSION="0.1.0"
BASELINE_VERSION="ubuntu-26.04"
RELEASE_DATE="2026-06-28"
```

---

## Version Types

| Version | Purpose |
|---|---|
| Toolkit version | Overall release version of the shell toolkit. |
| Installer version | Installer implementation version. |
| Standards version | Toolkit compatibility metadata; not an engineering-policy authority. |
| Baseline version | Operating-system baseline family. |
| Command version | Optional version for individual command modules. |

---

## Toolkit Release Value

`TOOLKIT_VERSION` follows the Engineering Manual's versioning standard. Current
ShellToolkit release lines use values such as:

```text
1.0.0-alpha1
1.3.0-beta1
1.3.0-rc1
```

Label meaning and compatibility rules come from the Engineering Manual rather
than this document.

---

## Script Header Versions

Script headers may state:

```text
Version     : reads VERSION
```

This means the script reports the repository version at runtime.

If an individual script has its own implementation version, it may define a local variable such as:

```bash
INSTALL_VERSION="2.1.0-alpha1"
```

That script version does not replace the toolkit version.

---

## Release Integration

The Engineering Manual governs tag format and release procedure. ShellToolkit's
additional readiness gates validate README, ROADMAP, CHANGELOG, VERSION,
manifest, installer, generated documentation, and doctor state before release
activity. See [`Release-Checklist.md`](Release-Checklist.md).
