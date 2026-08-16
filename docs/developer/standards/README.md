# ShellToolkit Implementation Standards

This directory contains ShellToolkit-specific implementation requirements and
references. It does not define ecosystem-wide engineering policy.

`CaptainCronos-02-Engineering-Manual` is authoritative for ecosystem standards,
including Bash, repository structure, Markdown, versioning, Git, and releases.
These local documents supplement that policy only where ShellToolkit's
implementation needs a concrete contract. If they conflict on a general policy
question, the Engineering Manual wins.

---

## Standards Index

| Standard | Title | Purpose |
|---|---|---|
| [CC-STD-001](CC-STD-001-Script-Headers.md) | Script Headers | ShellToolkit command metadata contract. |
| [CC-STD-002](CC-STD-002-Repository-Layout.md) | Repository Layout | ShellToolkit path responsibilities and cleanliness contract. |
| [CC-STD-003](CC-STD-003-Versioning.md) | Version Representation | ShellToolkit `VERSION` fields and consumers. |
| [CC-STD-004](CC-STD-004-Bash-Coding-Standards.md) | Bash Conventions | Engineering Manual reference plus toolkit helper conventions. |
| [CC-STD-005](CC-STD-005-Documentation-Standards.md) | Documentation | Engineering Manual reference plus toolkit ownership rules. |
| [CC-STD-006](CC-STD-006-Release-Process.md) | Release Gates | Engineering Manual workflow plus toolkit-specific checks. |
| [CC-STD-007](CC-STD-007-Command-Framework.md) | Command Framework | `cc` command structure and module behavior. |

---

## Authority Rule

These documents govern ShellToolkit implementation only. They are not templates
or default rules for other repositories.
