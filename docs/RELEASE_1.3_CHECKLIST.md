# Captain Cronos 1.3.x Framework Completion Checklist

## Milestone Definition

Version 1.3.x marks the transition from framework construction to framework completion.

The goal of 1.3.x is to stabilize the core namespaces and confirm that the toolkit can support real feature plugins without changing the core architecture.

## Completion Areas

### Stable Namespaces

Canonical namespaces:

- cc env
- cc storage
- cc asset
- cc docs
- cc plugin
- cc release
- cc update
- cc doctor

Compatibility commands may remain, but documentation should prefer namespace forms.

Status targets:

- Namespace commands exist.
- Namespace help output is clear.
- Compatibility commands remain functional.
- Registry shows namespace commands correctly.
- Strict audit passes.

### Storage Plugin

Canonical storage entrypoint:

- cc storage

Required subcommands:

- inventory
- drives
- smart
- test
- report
- qualify
- burnin
- workbench
- deps
- status

Status targets:

- Existing drive commands remain compatible.
- Storage namespace dispatches to tested implementations.
- Workbench flow supports live USB qualification.
- Storage dependencies can be checked independently.

### Environment Plugin

Canonical environment entrypoint:

- cc env

Required subcommands:

- path
- path --fix
- shell
- host
- doctor

Status targets:

- PATH health reports PASS, WARN, or FAIL.
- Duplicate PATH entries are warnings.
- Missing required PATH entries are failures.
- Repair mode creates guarded PATH entries.
- Host identity and platform summary are available.

### Asset Database

Canonical asset entrypoint:

- cc asset

Required minimum lifecycle states:

- new
- inventory
- testing
- qualified
- production
- watch
- failed
- retired

Status targets:

- Assets are host-scoped.
- Drive reports can update asset records.
- Asset records can be listed, inspected, and exported.
- Future storage qualification can update asset state automatically.

### Installation Framework

Canonical installation entrypoint:

- cc install

Required behavior:

- Dependency gate runs before file changes.
- Repository verification runs before install.
- Shell syntax is checked before install.
- Existing shell files are backed up before replacement.
- cc launcher is installed into ~/bin.
- PATH guidance is provided.

Status targets:

- Install is first-time enrollment path.
- Update is recurring maintenance path.
- Install supports recovery/testing bypasses where appropriate.

### Workbench Support

Canonical workbench entrypoint:

- cc workbench

Required behavior:

- Network status check.
- Repository clone or update flow.
- Toolkit install.
- Host initialization as workbench.
- Self-test unless disabled.
- Suggested drive qualification commands.

Status targets:

- Dry-run by default.
- Apply mode explicit.
- Designed for Ubuntu/Mint live USB sessions.
- Does not require installation on TrueNAS.

## Quality Gates

Before tagging 1.3.0-alpha1:

```text
cc selftest
cc audit --strict
cc docs lint
cc verify executable
cc release check
git status --short
```

Expected final state:

```text
strict audit clean
executable audit clean
docs lint clean
release check clean
working tree clean
```

## Release Boundary

1.3.x should not attempt full TrueNAS integration, remote host management, or Bitcoin node automation.

Those belong to later milestones.

1.3.x is complete when the framework can reliably initialize, inspect, update, validate, and support storage/workbench operations through stable namespaces.
