# setupmyenv

One-command bootstrap scripts that turn a **fresh machine, cloud VM, or
container** into a ready-to-use software-development box.

Each script is a single self-contained file meant to be piped straight from
GitHub into your shell. It installs the OS build dependencies,
[`asdf`](https://asdf-vm.com), a pinned polyglot toolchain (Node.js, Python, Go,
Java, Flutter, Terraform, kubectl, Helm, SOPS, Ruby) and the Android
command-line SDK, then wires everything into your shell profile.

> Full specification, design notes, bug list and roadmap: [`SPEC.md`](./SPEC.md).
> Version history: [`CHANGELOG.md`](./CHANGELOG.md).

## Which script do I run?

| Script          | Target                                                          | Mode          |
|-----------------|----------------------------------------------------------------|---------------|
| `ubuntu.sh`     | Ubuntu 20.04 / 22.04 / 24.04 — desktop or cloud VM (has `sudo`) | `vm`          |
| `docker.sh`     | An Ubuntu base image, building a container as `root`            | `container`   |
| `macos.sh`      | A local macOS workstation (admin user)                          | `workstation` |
| `macincloud.sh` | Hosted macOS without admin rights (e.g. MacinCloud) + GitLab CI | `noadmin`     |

`docker.sh` is `ubuntu.sh` pre-set to `--container`; `macincloud.sh` is
`macos.sh` pre-set to `--no-admin`. Any script also accepts the flag explicitly.

## Quick start

### Ubuntu

```bash
# configure ~/.profile (bash)
curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh | bash

# configure ~/.zshrc (zsh)
curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh | bash -s -- --shell zsh
```

The legacy form still works:

```bash
ENV=zsh /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh)"
```

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/macos.sh | bash
```

Install the Xcode Command Line Tools first:

```bash
xcode-select --install && sudo xcodebuild -license accept
```

### Hosted macOS without admin (MacinCloud + GitLab runner)

Homebrew goes into `$HOME/.brew`; the same configuration is written to both
`~/.zshrc` and `~/.bashrc` so a bash-based runner picks up the toolchain too.

```bash
curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/macincloud.sh | bash
```

### Container image

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl ca-certificates
RUN curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/docker.sh | bash
```

## Options

Pass options after `bash -s --` when piping, or directly when running a local
copy.

| Flag                | Effect                                                        |
|---------------------|-------------------------------------------------------------|
| `--dry-run`         | Print every step, change nothing (`DRY_RUN=1` also works)    |
| `--no-android`      | Skip the Android SDK / command-line tools                    |
| `--no-flutter`      | Skip Flutter                                                 |
| `--shell bash\|zsh` | Which rc file to configure (default: auto from `$SHELL`)     |
| `--container`       | Container mode: run as root, no `sudo`, no Homebrew          |
| `--no-admin`        | macOS without admin (Homebrew into `$HOME/.brew`)            |
| `-h`, `--help`      | Usage                                                        |

Environment: `DRY_RUN=1`, `ENV=zsh|bash` (legacy alias for `--shell`),
`SETUPMYENV_MODE=…`, `SKIP_CHECKSUM=1`.

**Preview a run before committing to it:**

```bash
curl -fsSL .../ubuntu.sh | bash -s -- --dry-run
```

## What gets installed

1. OS build dependencies (`build-essential`, `git`, `curl`, `jq`, `unzip`,
   Python/Flutter build libs, …). On Ubuntu ≤ 22.04 the Debian `libssl1.1`
   package is side-loaded for tools still linked against OpenSSL 1.1.
2. Locale (`en_US.UTF-8`) and `GPG_TTY` (so GPG-signed git commits can prompt on
   the tty).
3. `asdf` — from its GitHub release binary on Linux, from Homebrew on macOS.
4. `asdf` runtimes (table below), with `legacy_version_file = yes` so a
   project's `.nvmrc` / `.python-version` is honoured when there is no
   `.tool-versions`.
5. `fastlane` (RubyGems) and `awscli` (official installer on Linux, Homebrew on
   macOS). macOS also gets `cocoapods`.
6. Android command-line tools + `platform-tools`, one platform, and build-tools,
   with SDK licenses accepted (unless `--no-android`).

Homebrew is **not** used on Linux any more.

### Pinned toolchain

Single source of truth: [`src/versions.env`](./src/versions.env). Run
`./build.sh` after editing.

| Tool                  | Version              |
|-----------------------|----------------------|
| Node.js               | `24.20.0` (LTS)      |
| Python                | `3.13.15`            |
| Go                    | `1.27.1`             |
| Java (Temurin)        | `temurin-25.0.4+7` (LTS) |
| Flutter               | `3.47.2-stable`      |
| Terraform             | `1.16.1`             |
| kubectl               | `1.37.0`             |
| Helm                  | `4.2.4` (Helm 4 GA)  |
| SOPS                  | `3.13.3`             |
| Ruby                  | `3.4.10`             |
| asdf                  | `0.20.0`             |
| Android cmdline-tools | build `14742923`     |
| Android platform / build-tools | `android-36` / `36.0.0` |

Notes:
- **Python** — latest `3.13` patch (widest ecosystem support). For `3.14`, set
  `PYTHON_VERSION=3.14.x`.
- **Helm 4** is GA and has CLI/flag changes vs Helm 3. For a pipeline that still
  needs Helm 3, set `HELM_VERSION=3.21.4`.
- **kubectl** tracks upstream stable; keep it within ±1 minor of your clusters
  if that matters to you.

## After it finishes

```bash
exec "$SHELL" -l          # reload PATH, asdf shims, JAVA_HOME, ANDROID_HOME, …
```

Verify:

```bash
asdf current
node --version && python --version && go version && java -version
flutter --version && terraform version && kubectl version --client
helm version && sops --version
```

Re-running is safe: profile edits are fenced with `# >>> setupmyenv:<block> >>>`
markers and skipped if already present.

## Development

The root scripts are **generated**. Do not edit them directly.

```
src/versions.env      # every pinned version
src/lib.sh            # shared: logging, dry-run, idempotent profile edits,
                      #         strict mode, checksum verification, asdf helpers
src/ubuntu.body.sh    # Ubuntu logic  (modes: vm, container)
src/macos.body.sh     # macOS logic   (modes: workstation, noadmin)
build.sh              # inlines the above into ./ubuntu.sh ./docker.sh
                      #                        ./macos.sh ./macincloud.sh
scripts/check-versions.sh   # compare versions.env against upstream "latest"
```

```bash
# edit src/…, then:
./build.sh              # regenerate the four root scripts
./build.sh --check      # CI gate: fail if the committed scripts are stale
```

CI (`.github/workflows/ci.yml`) runs shellcheck, the drift gate, a `--dry-run`
smoke matrix on Ubuntu 20.04/22.04/24.04 and macOS, an opt-in full install, and
a weekly `version-check` that opens an issue when a pin falls behind.

## Caveats

- SHA-256 checksums for the two directly-downloaded artifacts (the `libssl1.1`
  `.deb` and the Android zip) are wired but ship blank — verification is skipped
  with a warning until they are filled in per release.
- macOS `--no-admin` still clones Homebrew into `$HOME/.brew` (no admin-free
  official installer exists) and may fall back to source builds.

See [`SPEC.md`](./SPEC.md) §6–§7 for the tracked issues and remaining roadmap.
