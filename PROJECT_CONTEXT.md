
# PROJECT_CONTEXT.md
**Captain Cronos Engineering Platform**

**Status:** Canonical (Living Document)  
**Project Context Version:** 1.0.0  
**Toolkit Version:** v1.3.0-beta1 ("Blackbeard")  
**Last Reviewed:** 2026-07-06

---

# 1. Purpose

This document is the authoritative engineering context for the Captain Cronos Engineering Platform.

Every ChatGPT or Codex session must read this document before making changes. It defines the architecture, engineering philosophy, repository standards, development workflow, and long-term vision.

If implementation and this document disagree, stop and explain the conflict before changing code.

---

# 2. Mission

Build a professional engineering platform instead of a collection of shell scripts.

Every subsystem should be reusable, metadata-driven, modular, validated, documented, and maintainable.

---

# 3. Repository Ecosystem

| Repository | Purpose |
|------------|---------|
| CaptainCronos | High-level planning and roadmaps |
| CaptainCronos-01-ShellToolkit | Primary executable toolkit |
| CaptainCronos-02-Engineering-Manual | Canonical engineering standards, policies, and documentation |
| Discipline-Curriculum | Educational content |

Repository health target:

- PASS only
- No dirty repositories
- No orphan feature branches
- main synchronized with origin

Validation:

```text
cc repos status
```

---

# 4. Engineering Philosophy

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

# 8. Development Workflow

For every engineering change:

1. Explain the architecture.
2. Create a feature branch.
3. Implement one logical feature.
4. Validate:

```text
cc verify
cc selftest
cc doctor
cc repos status
```

5. Commit with a semantic message.
6. Wait for approval.
7. Merge into main.
8. Push origin.
9. Delete feature branch.
10. Confirm repositories are clean.

---

# 9. Validation Requirements

A completed feature is not complete until validation succeeds.

Required quality gates include:

- cc verify
- cc selftest
- cc doctor
- cc repos status

---

# 10. Documentation Standards

The following files are first-class project artifacts:

- README.md
- ROADMAP.md
- CHANGELOG.md
- VERSION
- PROJECT_CONTEXT.md

Documentation evolves with the code.

---

# 11. AI Session Rules

Every new AI session should begin by reading this document.

AI assistants should:

- preserve architecture
- extend shared infrastructure
- avoid duplication
- document design decisions
- validate before reporting success
- never merge unless requested

---

# 12. Current Platform Status

Completed:

- Repository management framework
- Repository health reporting
- Batch publishing safeguards
- Engineering Manual
- Prompt template library
- Prompt Engine
- Interactive prompt workflow
- Dynamic template discovery
- Session framework

Repository status is expected to remain clean and synchronized.

---

# 13. Long-Term Vision

Expand the platform into a complete engineering environment supporting:

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

> Read PROJECT_CONTEXT.md before making changes. Treat it as the authoritative engineering context for this repository. Follow its architecture, coding standards, Git workflow, validation requirements, and engineering philosophy. If implementation conflicts with PROJECT_CONTEXT.md, explain the conflict before modifying code.

---

# 15. Living Document

PROJECT_CONTEXT.md is intended to evolve alongside the Captain Cronos Engineering Platform and should remain the primary onboarding document for both human contributors and AI assistants.
