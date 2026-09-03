# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Repository structure

- **The root scripts are now generated.** Edit `src/versions.env`, `src/lib.sh`,
  `src/ubuntu.body.sh` or `src/macos.body.sh`, then run `./build.sh`. CI fails if
  the committed `ubuntu.sh` / `docker.sh` / `macos.sh` / `macincloud.sh` drift
  from `src/`. The generated files stay single, self-contained, and safe to
  `curl | bash` — existing URLs are unchanged.
- `docker.sh` and `macincloud.sh` are no longer maintained by hand: they are the
  Ubuntu body in **container** mode and the macOS body in **no-admin** mode.
- Added `CHANGELOG.md` and a GitHub Actions pipeline (`.github/workflows/ci.yml`):
  shellcheck, build-drift gate, a dry-run smoke matrix on Ubuntu 20.04/22.04/24.04
  and macOS, an opt-in full-install job, and a weekly `version-check`
  (`scripts/check-versions.sh`) that files an issue when a pin is behind upstream.

### Added

- `--dry-run` — print every step without touching the system (`DRY_RUN=1` also
  works).
- `--no-android`, `--no-flutter` — skip those components.
- `--container` / `--no-admin` — pick the mode explicitly on any script.
- `--shell bash|zsh` — choose which rc file to configure (auto-detected from
  `$SHELL` otherwise; `ENV=zsh|bash` still honoured).
- `-h` / `--help`.
- `set -eEuo pipefail` with an error trap that reports the failing line; the
  whole run is wrapped in `main "$@"` so a truncated download cannot execute a
  partial script.
- Idempotent profile edits — configuration is written between
  `# >>> setupmyenv:<block> >>>` fences and re-runs are no-ops instead of
  appending duplicates.
- Optional SHA-256 verification of directly-downloaded artifacts (the
  `libssl1.1` `.deb` and the Android cmdline-tools zip). Pins live in
  `versions.env`; blank means "skip with a warning". `SKIP_CHECKSUM=1` opts out.

### Changed

- **Toolchain re-baselined (2026-09-03):**

  | Tool    | Old                     | New                |
  |---------|-------------------------|--------------------|
  | Node.js | 22.20.0                 | 24.20.0 (LTS)      |
  | Python  | 3.10.18                 | 3.13.15            |
  | Go      | 1.25.1                  | 1.27.1             |
  | Java    | adoptopenjdk-17.0.16+8  | temurin-25.0.4+7   |
  | Flutter | 3.35.5-stable           | 3.47.2-stable      |
  | Terraform | 1.13.3                | 1.16.1             |
  | kubectl | 1.34.1                  | 1.37.0             |
  | Helm    | 3.19.0                  | 4.2.4 (Helm 4 GA)  |
  | SOPS    | 3.11.0                  | 3.13.3             |
  | Ruby    | (implicit)              | 3.4.10 (pinned)    |
  | Android cmdline-tools | 13114758     | 14742923           |
  | Android platform / build-tools | android-30 / 32.0.0 | android-36 / 36.0.0 |

- **No Homebrew on Linux.** `asdf` is installed from its GitHub release binary,
  `awscli` from the official installer, `fastlane` from RubyGems. This removes
  the unsupported `git clone … ~/.brew` install and makes the container and VM
  paths converge. Homebrew is still used on macOS.
- **Terraform is installed once**, via `asdf` (it was previously installed by
  both `asdf` and Homebrew).
- macOS no longer sources the removed `libexec/asdf.sh`; `asdf` is put on `PATH`
  via its shims directory, matching Linux.
- The script no longer `source`s your rc file mid-run (that aborted under bash
  when the target was a real `~/.zshrc`). `PATH` changes are applied to the
  script's own process instead.
- Shell completion is written for the *target* shell (`asdf completion zsh` for
  zsh, `bash` for bash) instead of always bash.
- Locale generation on Ubuntu runs with `sudo` / `locale-gen` (it silently
  failed before).
- The OpenSSL 1.1 `.deb` shim is gated to Ubuntu ≤ 22.04 in every script
  (`docker.sh` previously ran an unbounded, stale-filename download that broke on
  22.04 and 24.04).

### Fixed

- `docker.sh` on Ubuntu 22.04 / 24.04 (`lsb-core`, stale `deb10u4` filename,
  unbounded OpenSSL shim, inconsistent `sudo`).
- zsh flow on Ubuntu leaving `brew` / `asdf` off `PATH`.
- `macincloud.sh` `sed 's/.zsh/.bash/g'` (greedy, unescaped `.`) — the `.bashrc`
  mirror is now produced by writing the same fenced blocks to both files.
- Hardcoded Intel `/usr/local/opt/ruby` `PATH` entry on macOS.

### Known gaps

- SHA-256 pins in `versions.env` ship blank (verification is wired but not
  enforced). They rotate on every version bump and need to be filled in from a
  trusted source per release.
- Homebrew in macOS **no-admin** mode still uses a `$HOME/.brew` clone (there is
  no admin-free official installer); it falls back to source builds.
