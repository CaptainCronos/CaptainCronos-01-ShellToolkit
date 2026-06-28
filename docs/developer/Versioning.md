# Versioning

Captain Cronos Shell Toolkit uses explicit version files and release labels to keep the toolkit auditable.

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
| Standards version | Version of governing engineering standards. |
| Baseline version | Operating-system baseline family. |
| Command version | Optional version for individual command modules. |

---

## Pre-release Labels

The toolkit may use semantic pre-release labels:

```text
alpha   actively changing architecture
beta    feature set stabilizing
rc      release candidate
stable  production release
```

Examples:

```text
1.0.0-alpha1
2.0.0-alpha
2.0.0-beta1
2.0.0-rc1
2.0.0
```

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

## Release Tags

Release tags should use this format:

```text
v2.0.0-alpha
v2.0.0-beta1
v2.0.0
```

Tagging should only occur after README, ROADMAP, CHANGELOG, VERSION, manifest, installer, and doctor checks are aligned.
