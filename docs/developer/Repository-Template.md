# Repository Template Definition

This document defines the canonical starting structure for future Captain Cronos repositories.

The Shell Toolkit is the reference implementation. Future repositories should follow this template unless the project roadmap explicitly approves a different layout.

---

## Purpose

A standard repository template ensures that every Captain Cronos project starts with:

- consistent documentation
- consistent versioning
- consistent release process
- predictable install and verification structure
- reusable engineering standards
- predictable automation targets

---

## Canonical Template

```text
RepositoryName/
├── README.md
├── ROADMAP.md
├── CHANGELOG.md
├── VERSION
├── manifest.yml
├── LICENSE
├── archive/
│   └── README.md
├── assets/
│   ├── README.md
│   └── images/
│       └── README.md
├── config/
│   └── README.md
├── docs/
│   ├── README.md
│   ├── user/
│   │   └── README.md
│   └── developer/
│       ├── README.md
│       ├── Architecture.md
│       ├── Engineering.md
│       ├── Repository-Layout.md
│       ├── Versioning.md
│       └── standards/
│           └── README.md
├── examples/
│   └── README.md
├── install/
│   └── README.md
├── lib/
│   └── README.md
├── plugins/
│   └── README.md
├── releases/
│   └── README.md
├── templates/
│   └── README.md
├── tests/
│   └── README.md
└── tools/
    ├── README.md
    └── commands/
        └── README.md
```

---

## Optional Directories

Repositories may add domain-specific directories when justified.

Examples:

| Repository Type | Optional Directories |
|---|---|
| Shell Toolkit | `bash/`, `baseline/`, `defaults/` |
| Linux Toolkit | `packages/`, `systemd/`, `diagnostics/` |
| Server Toolkit | `services/`, `firewall/`, `monitoring/` |
| Bitcoin Toolkit | `bitcoin/`, `electrs/`, `rpc-explorer/`, `wallets/` |
| TrueNAS Toolkit | `datasets/`, `shares/`, `replication/` |
| Instructor Toolkit | `lesson-plans/`, `rubrics/`, `checklists/` |

Optional directories must be documented in that repository's `README.md` and `docs/developer/Repository-Layout.md`.

---

## Required Files

### README.md

Primary project overview. Must explain:

- project purpose
- current milestone
- installation or usage
- repository layout summary
- documentation links

### ROADMAP.md

Defines milestones, current work, planned work, and exit criteria.

### CHANGELOG.md

Tracks user-visible and engineering changes by release or milestone.

### VERSION

Stores repository version fields.

### manifest.yml

Stores machine-readable metadata and future automation targets.

### LICENSE

Defines project licensing.

---

## Required Documentation

Developer-focused repositories should include:

```text
docs/developer/Architecture.md
docs/developer/Engineering.md
docs/developer/Repository-Layout.md
docs/developer/Versioning.md
docs/developer/standards/
```

User-facing projects should include:

```text
docs/user/
```

---

## Command Framework Template

If the repository exposes operational commands, use:

```text
tools/
└── commands/
```

The public command front-end should dispatch to command modules rather than containing all logic directly.

---

## Release Template

Every repository should support a release flow based on:

```text
README.md
ROADMAP.md
CHANGELOG.md
VERSION
manifest.yml
docs/developer/Release-Checklist.md
docs/developer/Verification-Checklist.md
```

---

## Template Rule

The template is a starting point, not clutter. Empty directories should contain short `README.md` files explaining their future purpose.

A directory that has no documented purpose should not exist.
