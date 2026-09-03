# shellcheck shell=bash
#@include versions.env
#@include lib.sh

# ==========================================================================
# Ubuntu / Debian body  (modes: vm, container)
#   - no Homebrew on Linux (SPEC.md B5): asdf comes from its GitHub release,
#     awscli from the official installer, fastlane from RubyGems
# ==========================================================================

export DEBIAN_FRONTEND=noninteractive

apt_base() {
  step "apt: base packages and build dependencies"
  priv apt-get update
  priv env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl wget git make jq unzip xz-utils gnupg locales pkg-config \
    build-essential llvm clang cmake ninja-build \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev \
    libyaml-dev libgmp-dev libgdbm-dev \
    tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libgtk-3-dev \
    apt-transport-https software-properties-common
}

openssl11_shim() {
  local rel major
  rel="$( . /etc/os-release 2>/dev/null; printf '%s' "${VERSION_ID:-0}" )"
  major="${rel%%.*}"
  if [ "${major:-0}" -ge 23 ] 2>/dev/null; then
    log "Ubuntu ${rel}: libssl1.1 backward-compat shim not needed"
    return 0
  fi
  if dpkg -s libssl1.1 >/dev/null 2>&1; then
    log "libssl1.1 already installed"
    return 0
  fi
  step "openssl 1.1 backward-compat shim (Ubuntu ${rel})"
  download "${LIBSSL1_DEB_BASEURL}/${LIBSSL1_DEB}" "/tmp/${LIBSSL1_DEB}" "${LIBSSL1_DEB_SHA256}"
  priv env DEBIAN_FRONTEND=noninteractive apt-get install -y "/tmp/${LIBSSL1_DEB}"
  is_dry_run || rm -f "/tmp/${LIBSSL1_DEB}"
}

gen_locale() {
  if locale -a 2>/dev/null | grep -qiE 'en_us\.utf-?8'; then
    log "locale en_US.UTF-8 already generated"
    return 0
  fi
  step "locale: en_US.UTF-8"
  if [ -f /etc/locale.gen ]; then
    priv sed -i 's/^# *\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    priv locale-gen
  else
    priv locale-gen en_US.UTF-8 || true
  fi
  priv update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || true
}

profile_core() {
  profile_block core <<'EOF'
# locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# gpg: route the pinentry prompt to the tty for signed git commits
export GPG_TTY=$(tty)
# user-local bin (asdf, awscli, ...)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
EOF
}

install_asdf() {
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  local cur=""
  if have asdf; then
    cur="$(asdf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  fi
  if [ -n "$cur" ] && [ "$cur" = "$ASDF_VERSION" ]; then
    log "asdf ${ASDF_VERSION} already installed"
  elif [ -n "$cur" ] && ! version_lt "$cur" "$ASDF_VERSION"; then
    log "asdf ${cur} present (newer than pinned ${ASDF_VERSION}) — keeping"
  else
    if [ -n "$cur" ]; then step "upgrade asdf ${cur} -> ${ASDF_VERSION}"
    else step "install asdf ${ASDF_VERSION}"; fi
    local arch tgz url
    arch="$(arch_tag)"
    [ "$arch" = unknown ] && die "unsupported CPU architecture: $(uname -m)"
    tgz="asdf-v${ASDF_VERSION}-linux-${arch}.tar.gz"
    url="https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/${tgz}"
    if is_dry_run; then
      log "[dry-run] fetch ${url} and extract 'asdf' into ~/.local/bin"
    else
      curl -fsSL --retry 3 --retry-delay 2 -o "/tmp/${tgz}" "$url"
      tar -xzf "/tmp/${tgz}" -C "$HOME/.local/bin" asdf
      chmod +x "$HOME/.local/bin/asdf"
      rm -f "/tmp/${tgz}"
    fi
  fi
  ensure_asdf_env
  if ! is_dry_run; then
    local ec=0
    "$HOME/.local/bin/asdf" --version >/dev/null 2>&1 || ec=$?
    case "$ec" in
      0) : ;;
      126) die "asdf will not execute (126). ~/.local/bin appears to be on a noexec mount ($HOME). Re-run with HOME set to a normal path." ;;
      127) die "asdf not found after install — extraction into ~/.local/bin failed." ;;
      *)   die "asdf installed but 'asdf --version' failed (exit $ec)." ;;
    esac
  fi
}

install_runtimes() {
  ensure_asdf_env
  asdf_install_tool nodejs    "$NODEJS_VERSION"
  asdf_install_tool python    "$PYTHON_VERSION"
  asdf_install_tool golang    "$GOLANG_VERSION"
  asdf_install_tool java      "$JAVA_VERSION"
  if [ "$DO_FLUTTER" = 1 ]; then
    asdf_install_tool flutter "$FLUTTER_VERSION"
  else
    log "skipping flutter (--no-flutter)"
  fi
  asdf_install_tool terraform "$TERRAFORM_VERSION"
  asdf_install_tool kubectl   "$KUBECTL_VERSION"
  asdf_install_tool helm      "$HELM_VERSION"
  asdf_install_tool sops      "$SOPS_VERSION"
  asdf_install_tool ruby      "$RUBY_VERSION"
  is_dry_run || asdf reshim
}

configure_asdf() {
  asdfrc_set legacy_version_file yes

  local jhook
  if [ "$TARGET_SHELL" = zsh ]; then jhook="set-java-home.zsh"; else jhook="set-java-home.bash"; fi

  profile_block asdf <<EOF
# asdf
export ASDF_DATA_DIR="\$HOME/.asdf"
export PATH="\$ASDF_DATA_DIR/shims:\$PATH"
[ -f "\$ASDF_DATA_DIR/plugins/java/${jhook}" ] && . "\$ASDF_DATA_DIR/plugins/java/${jhook}"
EOF

  is_dry_run && return 0
  have asdf || return 0
  mkdir -p "$HOME/.asdf/completions"
  if [ "$TARGET_SHELL" = zsh ]; then
    asdf completion zsh > "$HOME/.asdf/completions/_asdf" 2>/dev/null || true
    profile_block asdf-completion <<'EOF'
# asdf completions
fpath=("$HOME/.asdf/completions" $fpath)
autoload -Uz compinit && compinit
EOF
  else
    asdf completion bash > "$HOME/.asdf/completions/asdf.bash" 2>/dev/null || true
    profile_block asdf-completion <<'EOF'
# asdf completions
[ -f "$HOME/.asdf/completions/asdf.bash" ] && . "$HOME/.asdf/completions/asdf.bash"
EOF
  fi
}

activate_java() {
  is_dry_run && return 0
  if asdf where java >/dev/null 2>&1; then
    JAVA_HOME="$(asdf where java)"
    export JAVA_HOME
    log "JAVA_HOME=$JAVA_HOME"
  fi
}

install_extra_tools() {
  ensure_asdf_env
  if is_dry_run; then
    log "[dry-run] install/upgrade fastlane (RubyGems)"
  elif ! have gem; then
    warn "ruby/gem not on PATH — skipping fastlane"
  elif have fastlane; then
    step "fastlane: check for upgrade"
    gem update --no-document fastlane || warn "fastlane upgrade check failed (keeping current)"
  else
    step "fastlane (RubyGems)"
    gem install --no-document fastlane
  fi
  install_awscli
}

install_awscli() {
  if have aws; then log "aws cli already present: $(aws --version 2>&1 | head -1)"; return 0; fi
  step "aws cli v2"
  local arch
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) warn "aws cli: unsupported arch $(uname -m) — skipping"; return 0 ;;
  esac
  if is_dry_run; then
    log "[dry-run] install aws cli v2 (${arch}) into ~/.local/aws-cli"
    return 0
  fi
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" -o /tmp/awscliv2.zip
  ( cd /tmp && rm -rf aws && unzip -q awscliv2.zip \
    && ./aws/install --update --bin-dir "$HOME/.local/bin" --install-dir "$HOME/.local/aws-cli" )
  rm -rf /tmp/aws /tmp/awscliv2.zip
}

install_android() {
  if [ "$DO_ANDROID" != 1 ]; then log "skipping Android SDK (--no-android)"; return 0; fi
  step "Android command-line tools"
  local home="$HOME/android/sdk" url
  url="https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"

  if [ -x "$home/cmdline-tools/latest/bin/sdkmanager" ]; then
    log "cmdline-tools already installed at $home"
  else
    download "$url" /tmp/android-cmdline-tools.zip "$ANDROID_CMDLINE_TOOLS_SHA256"
    if ! is_dry_run; then
      mkdir -p "$home/cmdline-tools"
      rm -rf "$home/cmdline-tools/latest" "$home/cmdline-tools/cmdline-tools"
      unzip -q /tmp/android-cmdline-tools.zip -d "$home/cmdline-tools"
      mv "$home/cmdline-tools/cmdline-tools" "$home/cmdline-tools/latest"
      rm -f /tmp/android-cmdline-tools.zip
    fi
  fi

  profile_block android <<'EOF'
# android
export ANDROID_HOME="$HOME/android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
EOF

  export ANDROID_HOME="$home" ANDROID_SDK_ROOT="$home"
  export PATH="$PATH:$home/cmdline-tools/latest/bin"
  if is_dry_run; then
    log "[dry-run] accept licenses; sdkmanager platform-tools platforms;${ANDROID_PLATFORM} build-tools;${ANDROID_BUILD_TOOLS}"
    return 0
  fi
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager --install "platform-tools" "platforms;${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}"
}

main() {
  parse_args "$@"
  [ "$(os_id)" = linux ] || die "ubuntu.sh targets Linux — on macOS run macos.sh"

  if [ "$(id -u)" = 0 ] || [ "$MODE" = container ]; then SUDO=""; else SUDO="sudo"; fi
  if [ -n "$SUDO" ] && ! have sudo; then die "this mode needs root or sudo"; fi
  is_dry_run && warn "DRY RUN — no changes will be made"
  log "setupmyenv: mode=$MODE  os=$(os_id)/$(arch_tag)"

  resolve_shell_and_profiles
  apt_base
  openssl11_shim
  gen_locale
  profile_core
  install_asdf
  install_runtimes
  configure_asdf
  activate_java
  install_extra_tools
  install_android

  step "done"
  ok "toolchain ready — restart your shell:  exec \"\$SHELL\" -l"
}

main "$@"
