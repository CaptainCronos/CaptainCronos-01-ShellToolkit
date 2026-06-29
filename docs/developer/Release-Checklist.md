# Release Checklist

Use this checklist before creating an annotated release tag.

---

## 1. Documentation

- [ ] `README.md` is current.
- [ ] `ROADMAP.md` reflects the current milestone.
- [ ] `CHANGELOG.md` includes the release entry.
- [ ] `VERSION` contains the intended release version.
- [ ] `manifest.yml` has been reviewed.
- [ ] Developer documentation is current.
- [ ] Standards are current.

---

## 2. Repository Health

- [ ] Working tree is clean.
- [ ] Repository is on the intended branch.
- [ ] Local branch is synchronized with `origin/main`.
- [ ] No temporary migration scripts remain in active tool directories.
- [ ] No accidental backup files are tracked.
- [ ] No tracked file modes changed unintentionally.

---

## 3. Verification

Run:

```bash
install/verify.sh
cc doctor
bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions
```

Confirm:

- [ ] Repository verification passes.
- [ ] Bash syntax checks pass.
- [ ] Doctor output is acceptable.
- [ ] Any warnings are understood and documented.

---

## 4. Installer Test

Run:

```bash
install/install.sh --dry-run
```

Confirm:

- [ ] Dry-run completes.
- [ ] No repository files are modified.
- [ ] Report output is readable.
- [ ] Planned install paths are correct.

Optional live install test:

```bash
install/install.sh
source ~/.bashrc
cc version
cc doctor
```

Confirm:

- [ ] `cc` is installed into `~/bin`.
- [ ] `cc version` works.
- [ ] `cc doctor` works.
- [ ] Repository remains clean after install.

---

## 5. Tag Release

Create annotated tag:

```bash
git tag -a vX.Y.Z-label -m "Captain Cronos Shell Toolkit vX.Y.Z-label"
git push origin vX.Y.Z-label
```

---

## 6. Post-Release

- [ ] Confirm tag exists on GitHub.
- [ ] Confirm release notes are available or drafted.
- [ ] Update roadmap to the next milestone if needed.
