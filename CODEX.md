# CODEX.md

# Captain Cronos Engineering Platform
## AI Engineering Instructions

This repository is part of the Captain Cronos Engineering Platform.

Before making **any** modifications to this repository, establish engineering context by reading the required documentation in the order listed below.

---

# Required Reading Order

## 1. Engineering Manual

The canonical engineering standards are maintained in:

```
CaptainCronos-02-Engineering-Manual
```

Read the Engineering Manual in this order:

1. README.md
2. 00-Overview/
3. 01-Codex/
4. 02-Git/
5. 03-Architecture/
6. 04-Development/
7. 05-Operations/

Consult the following when appropriate:

- 06-Templates/
- 99-Appendix/
- adr/

The Engineering Manual defines:

- Engineering philosophy
- Git workflow
- Repository lifecycle
- Architecture standards
- Coding standards
- Documentation standards
- Validation requirements
- Release workflow

The Engineering Manual is the highest engineering authority.

Repository documents may define ShellToolkit implementation contracts and
operational requirements. They do not override the Engineering Manual on
ecosystem-wide engineering policy.

---

## 2. Repository Context

After reading the Engineering Manual, read:

```
PROJECT_CONTEXT.md
```

PROJECT_CONTEXT.md defines the current state of this repository, including:

- Architecture
- Implemented subsystems
- Current design decisions
- Engineering assumptions
- Roadmap
- AI-specific repository context

Treat PROJECT_CONTEXT.md as the canonical description of this repository.
Its authority is limited to ShellToolkit architecture, behavior, interfaces,
defaults, packaging, validation, and project state.

---

## 3. Repository Documentation

After PROJECT_CONTEXT.md, read repository documentation as needed:

- README.md
- ROADMAP.md
- CHANGELOG.md
- docs/

---

# Engineering Rules

When making changes:

- Preserve existing architecture.
- Prefer reusable infrastructure.
- Avoid duplicated logic.
- Build frameworks before features.
- Keep commands thin.
- Place business logic into shared libraries.
- Maintain semantic Git history.
- Keep documentation synchronized with implementation.
- Validate before reporting success.
- Never merge unless explicitly requested.

---

# Validation

Before considering work complete, run the required validation for the repository.

Typical validation includes:

```text
cc verify
cc selftest
cc doctor
cc repos status
```

Report validation results with every completed implementation.

---

# Conflict Resolution

If documentation conflicts, follow this order of precedence:

1. Engineering Manual
2. PROJECT_CONTEXT.md
3. Repository documentation
4. Existing implementation

This order applies after identifying the subject's scope. The Engineering
Manual always governs general engineering policy; ShellToolkit documentation
and implementation govern contracts unique to this toolkit.

If conflicts remain, stop and explain the conflict before modifying code.

Never silently choose one interpretation.

---

# Objective

Produce maintainable, reusable, well-documented engineering solutions that conform to the Captain Cronos Engineering Platform standards.

Favor long-term architecture over short-term implementation.
