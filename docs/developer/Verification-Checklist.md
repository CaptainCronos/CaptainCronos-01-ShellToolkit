# Verification Checklist

Use this checklist after pulling major changes, before committing, and before release tagging.

---

## 1. Repository State

```bash
git status
git branch --show-current
git log --oneline -5
```

Expected:

- [ ] On expected branch.
- [ ] Working tree clean unless actively developing.
- [ ] Recent commits look correct.

---

## 2. Repository Verification

```bash
install/verify.sh
```

Expected:

- [ ] Required directories exist.
- [ ] Required files exist.
- [ ] Bash syntax checks pass.
- [ ] Verification reports success.

---

## 3. Command Front-End

```bash
cc version
cc repo
cc help
```

Expected:

- [ ] `cc` is found in PATH.
- [ ] `cc version` reports toolkit version.
- [ ] `cc repo` reports the correct repository path.
- [ ] `cc help` lists expected commands.

---

## 4. Doctor Check

```bash
cc doctor
```

Expected:

- [ ] Repository checks are acceptable.
- [ ] Script syntax checks are acceptable.
- [ ] Installed command checks are acceptable.
- [ ] Any warnings are reviewed.

---

## 5. Shell Function Check

```bash
source ~/.bashrc
helpme version
helpme engineering
lstree --depth 2 .
```

Expected:

- [ ] `helpme` loads.
- [ ] `helpme engineering` lists engineering commands.
- [ ] `lstree` hides `.git` by default.
- [ ] No shell syntax errors appear.

---

## 6. Installer Dry-Run

```bash
install/install.sh --dry-run
```

Expected:

- [ ] Dry-run completes without writing files.
- [ ] Planned install paths are correct.
- [ ] No repository files are modified.

---

## 7. Repository Cleanliness After Verification

```bash
git status --short
```

Expected:

- [ ] No unintended modifications.
- [ ] No accidental executable-bit changes.
- [ ] No backup files staged or tracked.
