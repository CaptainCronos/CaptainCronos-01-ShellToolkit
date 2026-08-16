
# ShellToolkit Project Context

**Repository:** `CaptainCronos-01-ShellToolkit`

**Ecosystem:** Captain Cronos Engineering Platform

**Status:** Canonical ShellToolkit Context (Living Document)

**Project Context Version:** 1.0.0

**Toolkit Version:** v1.3.0-beta1 ("Blackbeard")

**Last Reviewed:** 2026-08-16

---

# 1. Purpose

This document is the authoritative project context for ShellToolkit. It
describes this repository's architecture, implementation contracts, current
state, validation requirements, and direction. It does not define engineering
policy for other Captain Cronos repositories.

Ecosystem-wide engineering standards, Git and repository lifecycle policy,
documentation conventions, architecture guidance, development practices, and
release workflow are governed by `CaptainCronos-02-Engineering-Manual`. If a
general engineering-policy rule here conflicts with that manual, the manual
wins. ShellToolkit documentation remains authoritative for behavior and
interfaces implemented by this repository.

---

# 2. Mission

Build ShellToolkit as a professional, integrated toolkit instead of a
collection of shell scripts.

Every subsystem should be reusable, metadata-driven, modular, validated, documented, and maintainable.

---

# 3. Repository Ecosystem

| Repository | Purpose |
|------------|---------|
| CaptainCronos | High-level planning and roadmaps |
| CaptainCronos-01-ShellToolkit | Primary executable toolkit |
| CaptainCronos-02-Engineering-Manual | Canonical engineering standards, policies, and documentation |
| CaptainCronos-02-VentoyUSB | Ventoy USB project |
| CaptainCronos-04-HouseToolkit | House operations toolkit |
| TechnicalEducationOS | Technical education operating-system project |
| Discipline-Curriculum | Educational content |
| HouseOfTartarus | House of Tartarus project |
| 5420-Rugged-Win11 | Rugged Windows 11 system project |

ShellToolkit's repository-management commands report against these operational
health targets:

- PASS only
- No dirty repositories
- No orphan feature branches
- main synchronized with origin

Validation:

```text
cc repos status
```

---

# 4. ShellToolkit Design Principles

Always:

- Build frameworks before features.
- Reuse infrastructure.
- Keep commands thin.
- Place business logic into shared libraries.
- Prefer metadata over hardcoded behavior.
- Keep documentation synchronized with implementation.
- Maintain semantic Git history.
- Validate every change.

Never:

- Duplicate logic.
- Hardcode menus.
- Create parallel implementations.
- Skip validation.
- Merge unapproved work.

---

# 5. Core Architecture

The toolkit is organized into reusable layers.

- Commands (public interface)
- Shared libraries
- Metadata
- Templates
- Documentation
- Validation
- Repository management

Public commands should orchestrate work rather than implement it.

---

# 6. Prompt Engine

Public command:

```text
cc prompt
```

Primary engine:

```text
lib/cc-prompt-engine.sh
```

Responsibilities include:

- template discovery
- metadata parsing
- question loading
- session management
- answer preservation
- rendering
- preview/edit
- clipboard support
- output hooks
- Ctrl+C recovery
- reusable navigation

Adding templates should require little or no shell code.

---

# 7. Prompt Templates

Location:

```text
templates/prompts/
```

Current templates include:

- feature
- framework
- workflow
- architecture
- bugfix
- docs

Templates are metadata-driven.

---

# 8. Development and Change Workflow

The Engineering Manual governs branching, commits, review, merge, and
repository lifecycle. For ShellToolkit changes, also:

1. Preserve the existing command and shared-library architecture.
2. Keep implementation and ShellToolkit documentation synchronized.
3. Run the project validation appropriate to the change:

```text
cc verify
cc selftest
cc doctor
cc repos status
```

4. Confirm that install, update, and validation paths do not unexpectedly
   modify tracked repository content.

---

# 9. Validation Requirements

A completed feature is not complete until validation succeeds.

Required quality gates include:

- cc verify
- cc selftest
- cc doctor
- cc repos status

---

# 10. Documentation Responsibilities

The following files are first-class project artifacts:

- README.md
- ROADMAP.md
- CHANGELOG.md
- VERSION
- PROJECT_CONTEXT.md

Documentation evolves with the code.

The Engineering Manual's Markdown and documentation standards govern general
documentation practice. ShellToolkit documentation owns only this project's
architecture, commands, runtime behavior, defaults, packaging, validation, and
operational guidance.

---

# 11. AI Session Rules

Every new AI session should begin by reading this document.

For work in this repository, AI assistants should:

- preserve architecture
- extend shared infrastructure
- avoid duplication
- document design decisions
- validate before reporting success
- follow the Engineering Manual for ecosystem policy
- never merge unless requested

---

# 12. Current ShellToolkit Status

Completed:

- Repository management framework
- Repository health reporting
- Batch publishing safeguards
- Prompt template library
- Prompt Engine
- Interactive prompt workflow
- Dynamic template discovery
- Session framework

Repository status is expected to remain clean and synchronized.

---

# 13. ShellToolkit Direction

Expand ShellToolkit's implementation capabilities to support:

- Prompt generation
- Documentation generation
- Repository lifecycle management
- Release management
- Asset management
- Storage management
- Live USB qualification
- Metadata-driven command generation
- AI-assisted engineering workflows

---

# 14. Canonical Startup Prompt

For any future ChatGPT or Codex session:

> Read the Engineering Manual for ecosystem policy, then read
> PROJECT_CONTEXT.md for ShellToolkit context. Treat ShellToolkit documentation
> as authoritative for this repository's implementation contracts. If a
> general engineering-policy rule conflicts with the Engineering Manual, the
> Engineering Manual wins.

---

# 15. Living Document

PROJECT_CONTEXT.md evolves with ShellToolkit and remains its primary project
context document. It supplements, and does not duplicate or replace, the
Engineering Manual.
