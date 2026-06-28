# CC-STD-006 — Release Process

A release is not complete until code, documentation, verification, and version records are aligned.

---

## Release Requirements

Before tagging a release:

- `README.md` is current.
- `ROADMAP.md` is current.
- `CHANGELOG.md` is current.
- `VERSION` is correct.
- `manifest.yml` is reviewed.
- Installer dry-run succeeds.
- Installer verification succeeds.
- `cc doctor` succeeds or warnings are documented.
- Repository working tree is clean.

---

## Tag Format

```text
vMAJOR.MINOR.PATCH[-label]
```

Example:

```bash
git tag -a v2.0.0-alpha -m "Captain Cronos Shell Toolkit v2.0.0-alpha"
git push origin v2.0.0-alpha
```

---

## Release Notes

Release notes should summarize:

- Added
- Changed
- Fixed
- Removed
- Known issues
- Upgrade instructions

---

## Rollback

Each release must preserve a rollback path through Git tags and user backups.
