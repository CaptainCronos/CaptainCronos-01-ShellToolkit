# CC-STD-005 — Documentation Standards

The Engineering Manual's `07-Standards/Markdown.md` and
`04-Development/Documentation.md` govern ecosystem-wide Markdown and
documentation practice. This page records ShellToolkit documentation ownership
and generation contracts.

---

## ShellToolkit Project Documents

ShellToolkit maintains:

```text
README.md
ROADMAP.md
CHANGELOG.md
```

Its contributor documentation includes:

```text
docs/developer/Architecture.md
docs/developer/Engineering.md
docs/developer/Repository-Layout.md
docs/developer/Versioning.md
```

---

## Project Maintenance

- Document architecture before expanding it.
- Update roadmap when project direction changes.
- Update changelog when behavior changes.
- Keep command usage examples current.
- Run ShellToolkit documentation lint and freshness checks after changing
  command metadata or generated references.

---

## Audience Split

ShellToolkit uses:

```text
docs/user/       End-user documentation
docs/developer/  Contributor and architecture documentation
```

---

## Source of Truth

Command help, inventory, and reference data are generated from ShellToolkit
command metadata. Generated files under `docs/generated/` must not be
hand-maintained as competing sources.
