# setupmyenv

One-command bootstrap scripts that turn a **fresh machine, cloud VM, or
container** into a ready-to-use software-development box.

Each script is a single file meant to be piped straight from GitHub into your
shell. It installs the OS build dependencies, [Homebrew](https://brew.sh),
[`asdf`](https://asdf-vm.com), a pinned polyglot toolchain (Node.js, Python, Go,
Java, Flutter, Terraform, kubectl, Helm, SOPS) and the Android command-line SDK,
then wires everything into your shell profile.

> See [`SPEC.md`](./SPEC.md) for the full specification, design notes, known
> issues, and roadmap.

## Which script do I run?

| Script          | Use it on                                                        | Default shell |
|-----------------|-----------------------------------------------------------------|---------------|
| `ubuntu.sh`     | Ubuntu 20.04 / 22.04 / 24.04 — desktop or cloud VM (has `sudo`) | bash or zsh   |
| `macos.sh`      | A local macOS workstation (admin user)                          | zsh           |
| `macincloud.sh` | Hosted macOS without admin rights (e.g. MacinCloud) + GitLab CI | zsh           |
| `docker.sh`     | An Ubuntu base image, building a container as `root`            | bash          |

## Prerequisites

**Ubuntu**
- A user with `sudo` (not needed for `docker.sh`, which runs as `root`).
- `curl` and `bash` (present on stock Ubuntu).
- To use the zsh flow: install zsh and, optionally,
  [Oh My Zsh](https://ohmyz.sh), then start a zsh session before running.
  ```bash
  sudo apt install -y zsh
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ```

**macOS**
- Xcode and the Command Line Tools, with the license accepted:
  ```zsh
  xcode-select --install
  sudo xcodebuild -license accept
  ```

## Usage

### Ubuntu

```bash
# bash login shell
ENV=bash /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh)"

# zsh login shell
ENV=zsh /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/ubuntu.sh)"
```

`ENV` only decides which profile file gets the configuration
(`~/.profile` for bash, `~/.zshrc` for zsh). The script itself runs under bash.

### macOS

```zsh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/macos.sh)"
```

### Hosted macOS (MacinCloud)

No admin rights required — Homebrew is installed into `~/.brew`. The script also
mirrors the generated `~/.zshrc` into `~/.bashrc` so a GitLab runner using a
bash shell picks up the same toolchain.

```zsh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/macincloud.sh)"
```

### Container image

Run inside your `Dockerfile` while building on top of an Ubuntu base image:

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl ca-certificates
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/docker.sh)"
```

## After it finishes

Restart your terminal (or `source` your profile) so the new `PATH`, `asdf`
shims, `JAVA_HOME`, `ANDROID_HOME`, `GPG_TTY` and locale settings take effect:

```bash
exec $SHELL -l
```

Verify:

```bash
asdf current
node --version && python --version && go version
java -version && flutter --version
terraform version && kubectl version --client && helm version && sops --version
```

## What gets installed

1. OS build dependencies (`build-essential`, `git`, `curl`, `jq`, `unzip`,
   Python/Flutter build libs, …). On Ubuntu ≤ 22.04 the Debian `libssl1.1`
   package is side-loaded for tools still linked against OpenSSL 1.1.
2. Locale (`en_US.UTF-8`) and `GPG_TTY` (so GPG-signed git commits can prompt on
   the tty).
3. Homebrew / Linuxbrew.
4. `asdf`, plus a few tools kept on Homebrew: `fastlane`, `awscli`, `ruby`
   (and on macOS `cocoapods`).
5. `asdf` runtimes (versions below).
6. `legacy_version_file = yes` so `asdf` honours a project's `.nvmrc` /
   `.python-version` when no `.tool-versions` is present.
7. Android command-line tools + `platform-tools`, a platform, and build-tools,
   with all SDK licenses accepted.

### Pinned toolchain

Versions live in clearly labelled variables at the top of each script — edit
them there before running, or bump and re-run to upgrade.

| Tool                  | Version                     |
|-----------------------|-----------------------------|
| Node.js               | `24.20.0` (active LTS)      |
| Python                | `3.13.15`                   |
| Go                    | `1.27.1`                    |
| Java (Temurin)        | `temurin-25.0.4+7` (LTS)    |
| Flutter               | `3.47.1-stable`             |
| Terraform             | `1.16.1`                    |
| kubectl               | `1.35.2`                    |
| Helm                  | `4.2.4`                     |
| SOPS                  | `3.13.3`                    |
| Android cmdline-tools | build `14742923`            |
| Android platform      | `android-36`                |
| Android build-tools   | `36.0.0`                    |

Notes:
- **Python** is pinned to the latest `3.13` patch (broadest ecosystem support).
  For `3.14`, set `PYTHON_VERSION=3.14.7`.
- **Helm 4** is the current GA line and has CLI/flag changes versus Helm 3. If a
  pipeline still needs Helm 3, set `HELM_VERSION=3.21.4`.
- **kubectl** is kept close to common managed-cluster versions; adjust to match
  your cluster (skew policy is ±1 minor).

## Customising

- **Change versions:** edit the `*_VERSION` variables at the top of the script.
- **Add a tool:** call the `tools_install` helper, e.g.
  `tools_install <asdf-plugin> <version>`.
- **Skip Android:** comment out the "android sdk and cli setup" block and the
  `sdkmanager` lines.

## Caveats

- The scripts **append** to your profile every run and are **not idempotent** —
  re-running duplicates the config blocks. Prefer a fresh machine, or clean the
  duplicated sections afterward.
- Downloaded artifacts are not checksum-verified.
- `docker.sh` currently lags `ubuntu.sh`'s fixes for Ubuntu 22.04 / 24.04.

See [`SPEC.md`](./SPEC.md) §6–§7 for the tracked bug list and roadmap.
