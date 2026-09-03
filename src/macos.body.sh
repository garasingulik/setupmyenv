# shellcheck shell=bash
#@include versions.env
#@include lib.sh

# ==========================================================================
# macOS body  (modes: workstation, noadmin)
#   workstation : official Homebrew, admin user
#   noadmin     : Homebrew cloned into $HOME/.brew (e.g. MacinCloud), also
#                 mirrors config into ~/.bashrc for a GitLab runner
# ==========================================================================

BREW=""   # resolved path to the brew binary

preflight() {
  [ "$(os_id)" = macos ] || die "macos.sh targets macOS — on Linux run ubuntu.sh"
  if ! xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools not detected."
    warn "Run:  xcode-select --install && sudo xcodebuild -license accept"
    is_dry_run || die "install the Command Line Tools first"
  fi
}

install_homebrew() {
  if have brew; then BREW="$(command -v brew)"; log "brew present: $BREW"; return 0; fi

  if [ "$MODE" = noadmin ]; then
    step "Homebrew into \$HOME/.brew (no admin)"
    if ! is_dry_run; then
      [ -d "$HOME/.brew" ] || git clone --depth=1 https://github.com/Homebrew/brew "$HOME/.brew"
    fi
    BREW="$HOME/.brew/bin/brew"
    profile_block homebrew <<'EOF'
# homebrew
export PATH="$HOME/.brew/bin:$HOME/.brew/sbin:$PATH"
EOF
  else
    step "Homebrew (official installer)"
    if is_dry_run; then
      log "[dry-run] run Homebrew install.sh"
    else
      NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew
    elif [ -x /usr/local/bin/brew ]; then BREW=/usr/local/bin/brew
    else BREW="brew"; fi
    profile_block homebrew <<EOF
# homebrew
eval "\$($BREW shellenv)"
EOF
  fi

  if ! is_dry_run && [ -x "$BREW" ]; then eval "$("$BREW" shellenv)"; fi
}

install_brew_tools() {
  # asdf from Homebrew is fine (0.16+ Go binary); we DO NOT source asdf.sh
  local pkgs="asdf jq openssl@3 readline sqlite3 xz zlib tcl-tk libyaml"
  if [ "$MODE" != noadmin ]; then pkgs="$pkgs awscli fastlane cocoapods"; fi

  if is_dry_run; then log "[dry-run] brew install/upgrade: $pkgs"; return 0; fi

  local p missing="" outdated=""
  for p in $pkgs; do
    if "$BREW" list --versions "$p" >/dev/null 2>&1; then
      "$BREW" outdated --quiet "$p" 2>/dev/null | grep -q . && outdated="$outdated $p"
    else
      missing="$missing $p"
    fi
  done
  if [ -n "$missing" ]; then
    step "brew: install$missing"
    # shellcheck disable=SC2086
    "$BREW" install $missing
  fi
  if [ -n "$outdated" ]; then
    step "brew: upgrade$outdated"
    # shellcheck disable=SC2086
    "$BREW" upgrade $outdated || warn "brew upgrade reported an error (continuing)"
  fi
  [ -z "$missing$outdated" ] && log "brew tools already up to date"
  return 0
}

profile_core() {
  profile_block core <<'EOF'
# locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# gpg: route the pinentry prompt to the tty for signed git commits
export GPG_TTY=$(tty)
EOF
}

install_asdf_env() {
  ensure_asdf_env
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
  asdfrc_set java_macos_integration_enable yes

  profile_block asdf <<'EOF'
# asdf
export ASDF_DATA_DIR="$HOME/.asdf"
export PATH="$ASDF_DATA_DIR/shims:$PATH"
[ -f "$ASDF_DATA_DIR/plugins/java/set-java-home.zsh" ] && . "$ASDF_DATA_DIR/plugins/java/set-java-home.zsh"
EOF

  is_dry_run && return 0
  have asdf || return 0
  mkdir -p "$HOME/.asdf/completions"
  asdf completion zsh > "$HOME/.asdf/completions/_asdf" 2>/dev/null || true
  profile_block asdf-completion <<'EOF'
# asdf completions
fpath=("$HOME/.asdf/completions" $fpath)
autoload -Uz compinit && compinit
EOF
}

activate_java() {
  is_dry_run && return 0
  if asdf where java >/dev/null 2>&1; then
    JAVA_HOME="$(asdf where java)"; export JAVA_HOME
    log "JAVA_HOME=$JAVA_HOME"
  fi
}

install_extra_tools() {
  [ "$MODE" != noadmin ] && return 0   # workstation got these from brew
  ensure_asdf_env
  local install="" update=""
  if have fastlane; then update="$update fastlane"; else install="$install fastlane"; fi
  if have pod;      then update="$update cocoapods"; else install="$install cocoapods"; fi
  if is_dry_run; then
    log "[dry-run] install/upgrade fastlane cocoapods (RubyGems)"
  elif ! have gem; then
    warn "ruby/gem not on PATH — skipping fastlane/cocoapods"
  else
    if [ -n "$install" ]; then
      step "gem install$install (no-admin)"
      # shellcheck disable=SC2086
      gem install --no-document $install
    fi
    if [ -n "$update" ]; then
      step "gem: check upgrades for$update"
      # shellcheck disable=SC2086
      gem update --no-document $update || warn "gem upgrade check failed (keeping current)"
    fi
  fi
  have aws || warn "aws cli not installed (needs admin); install manually if required"
}

install_android() {
  if [ "$DO_ANDROID" != 1 ]; then log "skipping Android SDK (--no-android)"; return 0; fi
  step "Android command-line tools"
  local home="$HOME/Library/Android/sdk" url
  url="https://dl.google.com/android/repository/commandlinetools-mac-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"

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
export ANDROID_HOME="$HOME/Library/Android/sdk"
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
  is_dry_run && warn "DRY RUN — no changes will be made"
  log "setupmyenv: mode=$MODE  os=$(os_id)/$(arch_tag)"

  # macOS scripts always configure zsh unless told otherwise
  [ -z "$TARGET_SHELL" ] && TARGET_SHELL=zsh
  resolve_shell_and_profiles

  preflight
  profile_core
  install_homebrew
  install_brew_tools
  install_asdf_env
  install_runtimes
  configure_asdf
  activate_java
  install_extra_tools
  install_android

  step "done"
  ok "toolchain ready — restart your shell:  exec \"\$SHELL\" -l"
}

main "$@"
