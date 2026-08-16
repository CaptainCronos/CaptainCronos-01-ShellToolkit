# CC-STD-001 — Script Headers

Every executable ShellToolkit command must begin with the metadata header used
by the `cc` registry, audit, help, and documentation generators. This is a
ShellToolkit interface contract, not an ecosystem-wide script-header policy.

---

## Required Header

```bash
#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : script-name
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Describe what this script does.
# ==============================================================================
```

---

## Required Behavior

Scripts should support these options where practical:

```bash
--help
--version
```

Runtime toolkit version data should come from the repository `VERSION` file.

---

## Purpose Line

The `Purpose` line should be concise because command discovery may use it for help output.

Good:

```text
Purpose     : Show toolkit version information.
```

Avoid vague text:

```text
Purpose     : Script stuff.
```
