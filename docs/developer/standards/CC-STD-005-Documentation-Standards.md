# CC-STD-005 — Documentation Standards

Documentation is part of the project, not an afterthought.

---

## Required Documents

Every Captain Cronos repository should include:

```text
README.md
ROADMAP.md
CHANGELOG.md
```

Engineering repositories should also include:

```text
docs/developer/Architecture.md
docs/developer/Engineering.md
docs/developer/Repository-Layout.md
docs/developer/Versioning.md
```

---

## Documentation Rules

- Document architecture before expanding it.
- Update roadmap when project direction changes.
- Update changelog when behavior changes.
- Keep command usage examples current.
- Prefer concise, practical documentation over long theory.

---

## Audience Split

Use:

```text
docs/user/       End-user documentation
docs/developer/  Contributor and architecture documentation
```

---

## Source of Truth

Where possible, help output and command indexes should be generated from script metadata to avoid duplicated documentation.
