# setupmyenv — Specification

## 1. Identity

**Repository:** `garasingulik/setupmyenv` (`git@github.com:garasingulik/setupmyenv.git`)

**What it is:** A collection of single-file shell bootstrap scripts meant to be
`curl`-piped into a fresh `bash`/`zsh` session to provision a brand-new
machine, VM, or container for polyglot software development. One command turns a
blank OS into a working toolchain.

**Invocation pattern (from `README.md`):**

```bash
# Ubuntu (configure ~/.profile)
curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh | bash

# Ubuntu, zsh + preview only
curl -fsSL .../ubuntu.sh | bash -s -- --shell zsh --dry-run

# macOS
curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/macos.sh | bash
```

The legacy `ENV=zsh /bin/bash -c "$(curl -fsSL …)"` form is still accepted.

## 2. Repository layout

The four root scripts are **generated** — single, self-contained, safe to
`curl | bash` — from shared sources:

```
src/versions.env      single source of truth for every pinned version
src/lib.sh            shared: arg parsing, logging, --dry-run, strict mode +
                      error trap, idempotent fenced profile edits, checksum
                      verification, asdf helpers
src/ubuntu.body.sh    Ubuntu logic   — modes: vm, container
src/macos.body.sh     macOS logic    — modes: workstation, noadmin
build.sh              inlines the above -> ubuntu.sh docker.sh macos.sh macincloud.sh
                      (`./build.sh --check` is the CI drift gate)
scripts/check-versions.sh   compares versions.env against upstream "latest"
```

| Script          | = body / mode              | Target                                        | Privilege        |
|-----------------|----------------------------|-----------------------------------------------|------------------|
| `ubuntu.sh`     | ubuntu / `vm`              | Ubuntu 20.04–24.04 desktop or cloud VM        | `sudo`           |
| `docker.sh`     | ubuntu / `container`       | Ubuntu base image, built as root              | root, no `sudo`  |
| `macos.sh`      | macos / `workstation`      | Local macOS workstation                       | admin            |
| `macincloud.sh` | macos / `noadmin`          | Hosted macOS (MacinCloud) + GitLab runner     | no admin         |

Homebrew is used **only on macOS**. On Linux `asdf` comes from its GitHub
release binary, `awscli` from the official installer, `fastlane` from RubyGems.

## 3. What the scripts do (common flow)

1. Parse flags (`--dry-run`, `--no-android`, `--no-flutter`, `--shell`,
   `--container`, `--no-admin`); resolve the target shell and the rc file(s) to
   configure (`noadmin` writes both `~/.zshrc` and `~/.bashrc`).
2. Install OS base packages / build dependencies (`apt` on Ubuntu, Homebrew deps
   on macOS).
3. On Ubuntu ≤ 22.04, side-load Debian's `libssl1.1` `.deb` (optionally
   checksum-verified) for tools still linked against OpenSSL 1.1.
4. Configure locale (`locale-gen`, with `sudo` where needed) and `GPG_TTY`.
5. Install `asdf` and put its shims directory on `PATH` for the current process
   (no `source`-ing of the user rc file).
6. Install `asdf` runtimes: `nodejs`, `python`, `golang`, `java`, `flutter`
   (unless `--no-flutter`), `terraform`, `kubectl`, `helm`, `sops`, `ruby`.
7. Configure `asdf`: `legacy_version_file = yes`, the asdf-java `JAVA_HOME` hook,
   and shell completion for the *target* shell.
8. Install `fastlane` + `awscli` (+ `cocoapods` on macOS).
9. Unless `--no-android`: download the Android command-line tools, relocate to
   `cmdline-tools/latest`, accept licenses, install `platform-tools`, the
   platform and build-tools from `versions.env`.
10. Write each config block once, fenced with `# >>> setupmyenv:<block> >>>`
    markers; print a "restart your shell" notice.

## 4. Pinned toolchain

Source: [`src/versions.env`](./src/versions.env). Last re-baselined 2026-09-03.

| Tool      | Version                    |
|-----------|----------------------------|
| Node.js   | `24.20.0` (active LTS)     |
| Python    | `3.13.15`                  |
| Go        | `1.27.1`                   |
| Java      | `temurin-25.0.4+7` (LTS)   |
| Flutter   | `3.47.2-stable`            |
| Terraform | `1.16.1`                   |
| kubectl   | `1.37.0`                   |
| Helm      | `4.2.4` (Helm 4 GA line)   |
| SOPS      | `3.13.3`                   |
| Ruby      | `3.4.10`                   |
| asdf      | `0.20.0`                   |
| Android cmdline-tools | `14742923` (`android-36`, `build-tools;36.0.0`) |

## 5. Design principles / constraints

- **Generated single file, no runtime dependencies.** `build.sh` inlines
  `versions.env` + `lib.sh` + a body into each root script so the published
  artifact still runs from `curl | bash` with nothing pre-installed. CI blocks
  drift between `src/` and the committed scripts.
- **One place to bump a version:** `src/versions.env`.
- **`asdf` is the runtime manager.** Anything with multiple concurrent versions
  in real projects goes through `asdf`, not the OS package manager or Homebrew.
- **Idempotent.** Profile edits are fenced blocks written once; re-runs are
  no-ops. Runtime installs skip work `asdf`/the SDK already did.
- **Fail loud.** `set -eEuo pipefail` + an `ERR` trap that names the failing
  line; the run is wrapped in `main "$@"` so a truncated download does nothing.
- **Previewable.** `--dry-run` prints every step and changes nothing.
- **Non-interactive.** `DEBIAN_FRONTEND=noninteractive`, `NONINTERACTIVE=1`,
  license prompts auto-accepted.

---

## 6. Bug list — status

The defects from the first revision of this spec, and where they stand.

| ID  | Summary                                                        | Status |
|-----|---------------------------------------------------------------|--------|
| B1  | `docker.sh` broken on Ubuntu 22.04/24.04 (`lsb-core`, stale `.deb` name, unbounded OpenSSL shim, inconsistent `sudo`) | **Fixed** — `docker.sh` is now the Ubuntu body in `container` mode; the OpenSSL shim is gated to Ubuntu ≤ 22.04 via `/etc/os-release`; no `lsb-*` package; `sudo` only when not root. |
| B2  | zsh flow leaves `brew`/`asdf` off `PATH` (script `source`s a bash-incompatible `~/.zshrc`) | **Fixed** — the script never sources the rc file; `PATH` is set in-process (`ensure_asdf_env`). |
| B3  | macOS sources the removed `libexec/asdf.sh`                   | **Fixed** — asdf shims dir is prepended to `PATH`, same as Linux. |
| B4  | `localedef` runs without `sudo`                               | **Fixed** — `priv locale-gen` / `priv update-locale`. |
| B5  | Homebrew-on-Linux via `git clone ~/.brew`                     | **Fixed** — no Homebrew on Linux at all. |
| B6  | `asdf completion bash` written into a zsh profile             | **Fixed** — completion generated for the target shell. |
| B7  | Hardcoded Intel `/usr/local/opt/ruby` `PATH` on macOS         | **Fixed** — removed; rely on `brew shellenv` + asdf shims. |
| B8  | Not idempotent — profile blocks appended every run            | **Fixed** — `profile_append_once` / `rcfile_line_once` with markers. |
| B9  | No strict mode, failures not surfaced                         | **Fixed** — `set -eEuo pipefail`, `ERR` trap, `main "$@"` wrapper. |
| B10 | Downloads not integrity-checked                               | **Partial** — `verify_sha256` + `download` wired for the `.deb` and Android zip; pins in `versions.env` ship blank (skip-with-warning) and still need filling per release. |
| B11 | `macincloud.sh` greedy `sed 's/.zsh/.bash/g'`                 | **Fixed** — the `.bashrc` mirror is produced by writing the same fenced blocks to both files. |
| B12 | Divergent Ubuntu scripts; retired `adoptopenjdk-`; 2021-era Android; Terraform installed twice | **Fixed** — single body; `temurin-`; `android-36`/`36.0.0`; Terraform via `asdf` only. |

### Remaining / new

- **B10** SHA-256 pins are blank. They rotate on every version bump; populate
  them from a trusted source as part of a release.
- macOS `noadmin` still uses a `$HOME/.brew` clone (no admin-free official
  installer) and may fall back to source builds.
- `check-versions.sh` does not cover Temurin or the Android SDK build numbers
  (awkward APIs) — those stay manual.

---

## 7. Roadmap

### 7.1 Fix bugs — done

- [x] **B1** `docker.sh` collapsed into the Ubuntu body (`--container`).
- [x] **B2** No more `source`-ing the rc file; `PATH` applied in-process.
- [x] **B3** macOS uses the asdf shims-on-`PATH` method.
- [x] **B4** Locale step runs with `sudo` / `locale-gen`.
- [x] **B8** Idempotent fenced profile edits.
- [x] **B9** `set -eEuo pipefail` + `ERR` trap + `main "$@"`.
- [x] **B5 / B6 / B7 / B11 / B12** swept.
- [x] `shellcheck` in CI (plus a build-drift gate and a dry-run smoke matrix).

### 7.2 Toolchain — done

- [x] Re-baselined 2026-09-03 (see §4). Java moved off the retired
      `adoptopenjdk-` prefix; Ruby and asdf now explicitly pinned.
- [x] Terraform installed once, via `asdf`.
- [x] `brew` extras reviewed: Homebrew dropped on Linux; `fastlane` → RubyGems,
      `awscli` → official installer, `ruby` → asdf. macOS keeps Homebrew for
      `asdf`, `awscli`, `fastlane`, `cocoapods`.
- [x] `src/versions.env` is the single edit point; `build.sh` regenerates.
- [x] Weekly `version-check` job (`scripts/check-versions.sh`) opens an issue
      when a pin falls behind upstream.

### 7.3 Longer-term — done / open

- [x] `--dry-run` mode.
- [x] Component opt-out flags (`--no-android`, `--no-flutter`); the body is split
      into functions.
- [x] Smoke-test workflow — dry-run matrix on Ubuntu 20.04/22.04/24.04 + macOS,
      plus an opt-in full-install job that asserts every tool resolves.
- [x] `verify_sha256` + `download` for the `.deb` and the Android zip
      (**pins still blank — B10**).
- [x] `CHANGELOG.md`.
- [ ] Populate the SHA-256 pins and enforce verification.
- [ ] Consider dropping the OpenSSL 1.1 shim entirely once no supported target
      needs it, and/or offering OpenTofu alongside Terraform.
- [ ] Optional `--print`/manifest output listing exact resolved versions.
