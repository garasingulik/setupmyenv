# setupmyenv — Specification

## 1. Identity

**Repository:** `garasingulik/setupmyenv` (`git@github.com:garasingulik/setupmyenv.git`)

**What it is:** A collection of single-file shell bootstrap scripts meant to be
`curl`-piped into a fresh `bash`/`zsh` session to provision a brand-new
machine, VM, or container for polyglot software development. One command turns a
blank OS into a working toolchain.

**Invocation pattern (from `README.md`):**

```bash
# Ubuntu, bash login shell
ENV=bash /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh)"

# Ubuntu, zsh login shell
ENV=zsh /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh)"

# macOS (zsh default)
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/macos.sh)"
```

## 2. Scripts

| Script          | Target environment                                   | Shell | Privilege model            | Homebrew location                     |
|-----------------|------------------------------------------------------|-------|----------------------------|---------------------------------------|
| `ubuntu.sh`     | Ubuntu 20.04 / 22.04 / 24.04 desktop or cloud VM     | bash (writes bash **or** zsh profile via `ENV`) | `sudo` available            | official installer → `/home/linuxbrew/.linuxbrew` |
| `macos.sh`      | Local macOS workstation                              | zsh   | admin user                 | official installer                    |
| `macincloud.sh` | Hosted macOS (MacinCloud) + GitLab runner use       | zsh   | **no admin**               | `git clone` → `~/.brew`               |
| `docker.sh`     | Ubuntu base image inside a container                 | bash  | runs as **root**, no `sudo`| `git clone` → `~/.brew`               |

## 3. What the scripts do (common flow)

1. Select the profile file to mutate (`~/.profile`, `~/.bashrc`, or `~/.zshrc`)
   from the `ENV` variable.
2. Pin a set of toolchain versions in shell variables at the top of the file.
3. Install OS base packages / build dependencies (`apt` on Ubuntu, Xcode CLT +
   `brew` deps on macOS).
4. On Ubuntu ≤ 22.04, side-load Debian's `libssl1.1` `.deb` for backward
   compatibility with tools still linked against OpenSSL 1.1.
5. Configure locale and `GPG_TTY`.
6. Install Homebrew / Linuxbrew.
7. Install [`asdf`](https://asdf-vm.com) plus a few brew-managed extras
   (`fastlane`, `awscli`, `terraform`, `ruby`, and on macOS `cocoapods`).
8. Configure `asdf` (`legacy_version_file = yes` for `.nvmrc` compatibility;
   `java_macos_integration_enable = yes` on macOS).
9. Install language/tool runtimes through `asdf` via the `tools_install` helper:
   `nodejs`, `python`, `golang`, `java`, `flutter`, `terraform`, `kubectl`,
   `helm`, `sops`.
10. Wire `JAVA_HOME` via the asdf-java hook and add shell completion.
11. Download the Android command-line tools, relocate them to
    `cmdline-tools/latest`, accept SDK licenses, and install `platform-tools`,
    `platforms;android-30`, `build-tools;32.0.0`.
12. Print a "restart your shell" notice.

## 4. Pinned toolchain (current `main`)

| Tool      | Version                    |
|-----------|----------------------------|
| Node.js   | `24.20.0` (active LTS)     |
| Python    | `3.13.15`                  |
| Go        | `1.27.1`                   |
| Java      | `temurin-25.0.4+7` (LTS)   |
| Flutter   | `3.47.1-stable`            |
| Terraform | `1.16.1`                   |
| kubectl   | `1.35.2`                   |
| Helm      | `4.2.4` (Helm 4 GA line)   |
| SOPS      | `3.13.3`                   |
| Android cmdline-tools | `14742923` (`android-36`, `build-tools;36.0.0`) |

_Last re-baselined 2026-09-03. Java identifier migrated from the retired
`adoptopenjdk-` prefix to `temurin-`._

## 5. Design principles / constraints

- **Single file, no dependencies.** Each script must run from `curl | sh` with
  nothing pre-installed beyond the OS and its default shell.
- **Version pinning at the top.** All upgradable versions live in clearly
  labelled variables in the first ~25 lines so a bump is a one-line change.
- **`asdf` is the runtime manager.** Anything with multiple concurrent versions
  in real projects goes through `asdf`, not the OS package manager or brew.
- **Profile file is append-only.** Configuration is added with `>>` to the
  user's rc file; the running shell is expected to be restarted afterwards.
- **Non-interactive.** `DEBIAN_FRONTEND=noninteractive`, `NONINTERACTIVE=1`,
  `yes | sdkmanager --licenses` — no prompts.

---

## 6. Known bugs / defects

Ordered roughly by severity. Line numbers refer to `main` at spec authoring time.

### B1 — `docker.sh` is broken on Ubuntu 22.04 and 24.04 (multiple causes)

`docker.sh` never received the fixes that landed in `ubuntu.sh` (PRs #3, #4, #5):

- **`apt install -y lsb-core`** (line 27) — `lsb-core` was dropped after Ubuntu
  20.04. On 22.04/24.04 this package does not exist and the whole `apt install`
  line fails. `ubuntu.sh` already switched to a conditional `lsb-base` /
  `lsb-core`.
- **Stale OpenSSL `.deb` filename** (lines 35–36) — still downloads
  `libssl1.1_1.1.1n-0+deb10u4_amd64.deb`. That exact file was superseded (PR #4
  moved `ubuntu.sh` to `deb10u6`) and older revisions get purged from the Debian
  security pool, so the URL 404s and `curl -o` writes an HTML error page that
  `apt install` then rejects.
- **No upper bound on the OpenSSL shim** (line 34: `-gt 21`) — on Ubuntu 24.04
  the `libssl1.1` deb cannot satisfy its `libc6` dependency and `apt` aborts.
  `ubuntu.sh` guards this with the `-gt 23` → `lsb-base` branch.
- **Inconsistent `sudo`** — line 27 uses bare `apt`, line 36 uses `sudo apt`.
  In a minimal container running as root, `sudo` is usually not installed, so
  line 36 fails with `sudo: command not found`.

### B2 — zsh flow on `ubuntu.sh` / `docker.sh` can leave `brew` off `PATH`

The script runs under `/bin/bash` but, when `ENV=zsh`, sets
`PROFILE_CONFIG=$HOME/.zshrc` and then repeatedly runs `source $PROFILE_CONFIG`
(lines 65, 72, 100, 122). A real `~/.zshrc` (e.g. Oh My Zsh) contains zsh-only
syntax that `bash` cannot parse; `source` aborts partway, so the
`brew shellenv` / asdf-shims `PATH` lines appended *after* the Oh My Zsh block
are never applied to the running shell. Subsequent `brew install …` and
`asdf …` calls then run against an incomplete `PATH`.
Fix direction: never `source` the user rc file from this script — apply the
needed `PATH` / `eval "$(brew shellenv)"` directly to the script's own
environment, and only *append* the persistent config for the next login shell.

### B3 — `macos.sh` / `macincloud.sh` use the removed `asdf.sh` sourcing mechanism

Both do `. $(brew --prefix asdf)/libexec/asdf.sh` (macos.sh:47,
macincloud.sh:49). `asdf` ≥ 0.16 (the Go rewrite, the version Homebrew installs
today) **removed shell sourcing entirely** — there is no `libexec/asdf.sh`. The
`.` command fails and `asdf` is not available for the rest of the script.
`ubuntu.sh` already uses the correct approach (prepend
`${ASDF_DATA_DIR:-$HOME/.asdf}/shims` to `PATH`). macOS scripts need the same
treatment.

### B4 — `localedef` runs without `sudo` in `ubuntu.sh`

`ubuntu.sh:52` calls `localedef … -A /usr/share/locale/locale.alias …` with no
`sudo` (unlike the `apt` calls around it). On a normal Ubuntu VM the user cannot
write under `/usr/share/locale`, so locale generation fails silently (no
`set -e`). Use `sudo localedef …` or `sudo locale-gen en_US.UTF-8`.

### B5 — Homebrew-on-Linux installed by `git clone` (`docker.sh`, `macincloud.sh`)

`git clone --depth=1 https://github.com/Homebrew/brew ~/.brew` is not a
supported Homebrew installation path on Linux. Bottles are built for the
default prefix; a custom `~/.brew` prefix forces source builds for most
formulae (very slow, frequently failing in a container). Prefer the official
`install.sh` (as `ubuntu.sh` does), or drop brew entirely for the container
case and install `asdf` + deps directly.

### B6 — `asdf completion bash` written into a zsh profile

`ubuntu.sh:99` / `docker.sh:89` always append `. <(asdf completion bash)` even
when `ENV=zsh`. zsh should get `asdf completion zsh`. Harmless-ish but produces
errors on every new shell.

### B7 — Hardcoded Intel Homebrew Ruby path in `macos.sh`

`macos.sh:100` appends `export PATH="/usr/local/opt/ruby/bin:$PATH"`. On Apple
Silicon Homebrew lives at `/opt/homebrew`, so this points at nothing. Use
`$(brew --prefix ruby)/bin` (and only if `ruby` was actually brew-installed).

### B8 — Scripts are not idempotent

Every run appends the same blocks (`# homebrew`, `# asdf`, `# android`, …) to
the profile with `>>`. Re-running to pick up a version bump silently duplicates
dozens of lines and stacks `PATH` entries. `macincloud.sh:102`
(`sed … ~/.zshrc >> ~/.bashrc`) compounds this on `~/.bashrc`.

### B9 — No `set -euo pipefail`, no error surfacing

None of the scripts enable strict mode. A failed `curl`, `apt`, `brew install`,
or `asdf install` does not stop the run; the script marches on and often prints
a cheerful "restart your terminal" at the end of a broken install. A
curl-piped installer especially needs to fail loud and early.

### B10 — `curl | bash` with no integrity verification

Downloaded artifacts (`libssl1.1` deb, Android cmdline-tools zip, Homebrew
installer, asdf plugins) are executed/installed with no checksum or signature
check. Acceptable for a personal dotfiles-style repo, but worth a note and at
least SHA-256 pinning for the pinned `.deb` and the Android zip.

### B11 — `macincloud.sh` `sed 's/.zsh/.bash/g'` is too greedy

The `.` is an unescaped regex metacharacter, so it also rewrites substrings like
`xyz` boundaries and, more importantly, mangles any path/token containing
`?zsh`. It should be `sed 's/\.zsh/\.bash/g'`, and even then blindly translating
a zsh rc to bash is fragile.

### B12 — Minor / cosmetic

- `docker.sh` still writes the `# locale` `LC_ALL/LANG` block that `ubuntu.sh`
  dropped — divergence between the two Ubuntu scripts that should be reconciled.
- `JAVA_VERSION` uses the retired `adoptopenjdk-` identifier; upstream is now
  Eclipse Temurin / Adoptium (`temurin-…`).
- `platforms;android-30` + `build-tools;32.0.0` are from 2021.
- `README.md` lists Terraform/kubectl/helm/sops as asdf-managed but `ubuntu.sh`
  *also* `brew install terraform` — Terraform ends up installed twice from two
  managers with a `PATH` race.

---

## 7. Roadmap

### 7.1 Fix bugs (do first)

- [ ] **B1** Port all `ubuntu.sh` fixes into `docker.sh`; ideally collapse the
      two into one `ubuntu.sh` with a `--container` / env flag instead of a
      forked file.
- [ ] **B2** Stop `source`-ing the user rc file mid-script; apply `PATH` changes
      to the current process directly.
- [ ] **B3** Replace `libexec/asdf.sh` sourcing in `macos.sh` / `macincloud.sh`
      with the asdf ≥ 0.16 shims-on-`PATH` method.
- [ ] **B4** Add `sudo` (or `locale-gen`) to the `ubuntu.sh` locale step.
- [ ] **B8** Make profile edits idempotent — guard each block with a marker
      check (`grep -q '# asdf' "$PROFILE_CONFIG" || { … }`) or write to a
      dedicated `~/.config/setupmyenv.sh` sourced once from the rc file.
- [ ] **B9** Add `set -euo pipefail` and an `ERR` trap that reports the failing
      line; consider wrapping the whole body in a `main() { … }; main "$@"` so a
      truncated `curl` download cannot execute a partial script.
- [ ] **B6 / B7 / B11 / B12** Sweep the smaller shell-correctness issues.
- [ ] Add `shellcheck` to CI (GitHub Actions) over all `*.sh`.

### 7.2 Update the toolchain

- [x] **Re-baselined 2026-09-03** across all four scripts (see §4 for the
      resulting versions):
  - Node.js `22.20.0` → `24.20.0` (active LTS).
  - Python `3.10.18` → `3.13.15` (3.14 available via one-line change).
  - Go `1.25.1` → `1.27.1`.
  - Java `adoptopenjdk-17.0.16+8` → `temurin-25.0.4+7` — retired `adoptopenjdk-`
    prefix replaced with `temurin-`.
  - Flutter `3.35.5` → `3.47.1`.
  - Terraform `1.13.3` → `1.16.1`.
  - kubectl `1.34.1` → `1.35.2`.
  - Helm `3.19.0` → `4.2.4` (Helm 4 GA; note the CLI/flag breaking changes vs
    Helm 3 — `HELM_VERSION=3.21.4` stays on the 3.x line).
  - SOPS `3.11.0` → `3.13.3`.
  - Android cmdline-tools `13114758` → `14742923`; `android-30`/`build-tools;32.0.0`
    → `android-36`/`build-tools;36.0.0`.
- [ ] Terraform is still installed by **both** asdf and `brew` — pick one (see
      B12). Consider offering OpenTofu.
- [ ] `brew` extras (`fastlane`, `awscli`, `cocoapods`, `ruby`) — confirm still
      needed; `awscli` and `ruby` are arguably better under asdf too.
- [ ] Add a `versions.env` file shared by all scripts so a bump is one edit in
      one place instead of four.
- [ ] Add a scheduled CI job (Dependabot-style or a cron workflow) that opens a
      PR when any pinned tool has a newer release.

### 7.3 Longer-term / nice to have

- [ ] Dry-run / `--print` mode that shows what would be installed.
- [ ] Split "OS base packages" / "Homebrew" / "asdf runtimes" / "Android" into
      functions with independent opt-out flags (`--no-android`, `--no-flutter`).
- [ ] Smoke-test workflow: run each script in a matrix of
      `ubuntu:20.04/22.04/24.04` containers (and a macOS runner) and assert
      `node`, `python`, `go`, `java`, `flutter --version`, `terraform`,
      `kubectl`, `helm`, `sops` all resolve.
- [ ] SHA-256 pin + verify the side-loaded `.deb` and the Android zip (B10).
- [ ] Publish a short `CHANGELOG.md` so consumers can see when versions moved.
- [ ] Optional: replace the OpenSSL 1.1 side-load with a documented note now
      that most tooling has moved to OpenSSL 3.
