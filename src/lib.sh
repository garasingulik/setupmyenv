# shellcheck shell=bash
# setupmyenv — shared library (inlined into every generated script by build.sh)
# Targets bash 3.2+ (macOS system bash) and runs under `set -eEuo pipefail`.

# --------------------------------------------------------------------------
# Output helpers
# --------------------------------------------------------------------------
if [ -t 2 ]; then
  _c_reset=$'\033[0m'; _c_blue=$'\033[34m'; _c_yellow=$'\033[33m'
  _c_red=$'\033[31m';  _c_green=$'\033[32m'; _c_dim=$'\033[2m'
else
  _c_reset=; _c_blue=; _c_yellow=; _c_red=; _c_green=; _c_dim=
fi

log()  { printf '%s==>%s %s\n'   "$_c_blue"   "$_c_reset" "$*" >&2; }
ok()   { printf '%s ok %s %s\n'  "$_c_green"  "$_c_reset" "$*" >&2; }
warn() { printf '%swarn%s %s\n'  "$_c_yellow" "$_c_reset" "$*" >&2; }
err()  { printf '%serr %s %s\n'  "$_c_red"    "$_c_reset" "$*" >&2; }
die()  { err "$*"; exit 1; }
step() { printf '\n%s--- %s ---%s\n' "$_c_dim" "$*" "$_c_reset" >&2; }

# --------------------------------------------------------------------------
# Error trap — report the failing line and bail
# --------------------------------------------------------------------------
_on_err() {
  local ec=$? line=${1:-?}
  trap - ERR   # report once, even though set -E would re-enter
  err "aborted at line ${line} (exit ${ec})"
  err "nothing was rolled back; fix the cause and re-run, or use --dry-run to preview"
  exit "$ec"
}

# --------------------------------------------------------------------------
# Dry-run plumbing
# --------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-0}"
is_dry_run() { [ "$DRY_RUN" = "1" ]; }

# run CMD...  — execute, or just print under --dry-run. Simple commands only
# (no pipes/redirections); guard those with `if is_dry_run; then ... fi`.
run() {
  if is_dry_run; then
    printf '   %s[dry-run]%s %s\n' "$_c_dim" "$_c_reset" "$*" >&2
    return 0
  fi
  "$@"
}

have()        { command -v "$1" >/dev/null 2>&1; }
require_cmd()  { have "$1" || die "required command not found: $1"; }

# version_lt A B  -> exit 0 (true) when A is strictly older than B.
# Compares dotted numeric components; non-numeric noise (v, -stable, temurin-,
# +build) is flattened first. Portable (no `sort -V`, which BSD lacks).
version_lt() {
  [ "$1" = "$2" ] && return 1
  awk -v a="$1" -v b="$2" 'BEGIN{
    gsub(/[^0-9.]+/,".",a); gsub(/[^0-9.]+/,".",b);
    na=split(a,A,"."); nb=split(b,B,"."); m=(na>nb?na:nb);
    for(i=1;i<=m;i++){ av=A[i]+0; bv=B[i]+0;
      if(av<bv) exit 0; if(av>bv) exit 1 }
    exit 1
  }'
}

# --------------------------------------------------------------------------
# Platform detection
# --------------------------------------------------------------------------
os_id() {
  case "$(uname -s)" in
    Linux)  printf 'linux' ;;
    Darwin) printf 'macos' ;;
    *)      printf 'unknown' ;;
  esac
}

arch_tag() {
  case "$(uname -m)" in
    x86_64|amd64)  printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    i386|i686)     printf '386' ;;
    *)             printf 'unknown' ;;
  esac
}

# priv CMD...  — run CMD with sudo when $SUDO is non-empty, else run it directly.
# Honours --dry-run via run().
SUDO="${SUDO:-}"
priv() {
  if [ -n "$SUDO" ]; then run sudo "$@"; else run "$@"; fi
}

# --------------------------------------------------------------------------
# CLI arguments  (DEFAULT_MODE is substituted by build.sh per output file)
# --------------------------------------------------------------------------
MODE="${SETUPMYENV_MODE:-@DEFAULT_MODE@}"
DO_ANDROID=1
DO_FLUTTER=1
TARGET_SHELL="${TARGET_SHELL:-}"

usage() {
  cat >&2 <<EOF
setupmyenv — provision a development toolchain

Usage: <script> [options]
   or: curl -fsSL <raw-url> | bash -s -- [options]

Options:
  --dry-run          Print every step without changing the system
  --no-android       Skip the Android SDK / command-line tools
  --no-flutter       Skip Flutter
  --container        Container mode: run as root, no sudo, no Homebrew
  --no-admin         macOS without admin rights (Homebrew into \$HOME/.brew)
  --shell <name>     Which rc file to configure: bash | zsh  (default: auto)
  -h, --help         This help

Environment:
  DRY_RUN=1          Same as --dry-run
  ENV=zsh|bash       Legacy alias for --shell
  SETUPMYENV_MODE=…  vm | container | workstation | noadmin
  SKIP_CHECKSUM=1    Do not verify download checksums (not recommended)
EOF
}

parse_args() {
  # legacy: ENV=zsh|bash selects the target shell
  if [ -z "$TARGET_SHELL" ] && [ -n "${ENV:-}" ]; then TARGET_SHELL="$ENV"; fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)     DRY_RUN=1 ;;
      --no-android)  DO_ANDROID=0 ;;
      --no-flutter)  DO_FLUTTER=0 ;;
      --container)   MODE=container ;;
      --no-admin)    MODE=noadmin ;;
      --shell)       shift; TARGET_SHELL="${1:-}" ;;
      --shell=*)     TARGET_SHELL="${1#*=}" ;;
      -h|--help)     usage; exit 0 ;;
      *)             err "unknown option: $1"; usage; exit 2 ;;
    esac
    shift
  done

  case "$MODE" in
    vm|container|workstation|noadmin) ;;
    *) die "invalid mode: $MODE" ;;
  esac
}

# --------------------------------------------------------------------------
# Shell / profile resolution
# --------------------------------------------------------------------------
PROFILE_FILES=()

resolve_shell_and_profiles() {
  if [ -z "$TARGET_SHELL" ]; then
    case "${SHELL:-}" in
      */zsh)  TARGET_SHELL=zsh ;;
      */bash) TARGET_SHELL=bash ;;
      *)      if [ "$(os_id)" = macos ]; then TARGET_SHELL=zsh; else TARGET_SHELL=bash; fi ;;
    esac
  fi
  case "$TARGET_SHELL" in
    zsh)  PROFILE_FILES=("$HOME/.zshrc") ;;
    bash)
      if [ "$(os_id)" = macos ]; then PROFILE_FILES=("$HOME/.bash_profile")
      else PROFILE_FILES=("$HOME/.profile"); fi
      ;;
    *) die "unsupported --shell: $TARGET_SHELL (want bash or zsh)" ;;
  esac
  # noadmin (MacinCloud + GitLab runner) also feeds a bash login shell
  if [ "$MODE" = noadmin ]; then PROFILE_FILES=("${PROFILE_FILES[@]}" "$HOME/.bashrc"); fi
  for _pf in "${PROFILE_FILES[@]}"; do [ -e "$_pf" ] || { is_dry_run || : > "$_pf"; }; done
  log "shell: $TARGET_SHELL   profile(s): ${PROFILE_FILES[*]}"
}

# profile_block MARKER  (content on stdin)
# Ensures EXACTLY ONE fenced block per profile file whose body matches the
# current content. Safe to run repeatedly:
#   - block absent      -> appended
#   - block present, stale (content changed between versions) -> rewritten
#   - block present, identical -> file left untouched (no churn)
# A stray/duplicate block from an older run is collapsed to one.
profile_block() {
  local marker="$1" content begin end f tmpc out
  begin="# >>> setupmyenv:${marker} >>>"
  end="# <<< setupmyenv:${marker} <<<"
  content="$(cat)"
  tmpc="$(mktemp)"; printf '%s\n' "$content" > "$tmpc"
  for f in "${PROFILE_FILES[@]}"; do
    [ -e "$f" ] || { is_dry_run || : > "$f"; }
    # Rebuild the file: the fresh block replaces the FIRST existing copy in
    # place (stable ordering across runs), any further stray copies are
    # dropped, and if the block is new it is appended after the last
    # non-blank line. An identical result means the file is left untouched.
    out="$(awk -v cf="$tmpc" -v b="$begin" -v e="$end" '
      FILENAME==cf { body[++m]=$0; next }
      $0==b { if (!seen) { lines[++n]="\001BLK\001"; seen=1 } drop=1; next }
      drop && $0==e { drop=0; next }
      drop { next }
      { lines[++n]=$0 }
      END {
        if (!seen) {
          while (n>0 && lines[n] ~ /^[ \t]*$/) n--
          if (n>0) lines[++n]=""
          lines[++n]="\001BLK\001"
        }
        for (i=1;i<=n;i++) {
          if (lines[i]=="\001BLK\001") {
            print b
            for (j=1;j<=m;j++) print body[j]
            print e
          } else print lines[i]
        }
      }
    ' "$tmpc" "$f" 2>/dev/null || true)"
    if [ -f "$f" ] && [ "$out" = "$(cat "$f")" ]; then
      log "profile block '${marker}' already current in ${f##*/}"
      continue
    fi
    if is_dry_run; then
      if [ -f "$f" ] && grep -qF "$begin" "$f" 2>/dev/null; then
        printf '   %s[dry-run]%s refresh block %s in %s\n' "$_c_dim" "$_c_reset" "$marker" "$f" >&2
      else
        printf '   %s[dry-run]%s add block %s to %s\n' "$_c_dim" "$_c_reset" "$marker" "$f" >&2
      fi
      continue
    fi
    printf '%s\n' "$out" > "$f"
    ok "profile block '${marker}' written to ${f##*/}"
  done
  rm -f "$tmpc"
}

# asdfrc_set KEY VALUE  — maintain a single `KEY = VALUE` line in ~/.asdfrc.
# Replaces an existing KEY line (even with a different value); adds it otherwise.
asdfrc_set() {
  local file="$HOME/.asdfrc" key="$1" val="$2" line
  line="$key = $val"
  [ -e "$file" ] || { is_dry_run || : > "$file"; }
  if [ -f "$file" ] && grep -qxF "$line" "$file" 2>/dev/null; then
    log ".asdfrc: $key already set"
    return 0
  fi
  if is_dry_run; then
    printf '   %s[dry-run]%s .asdfrc set %s\n' "$_c_dim" "$_c_reset" "$line" >&2
    return 0
  fi
  if [ -f "$file" ] && grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null; then
    sed -i.bak "s|^[[:space:]]*${key}[[:space:]]*=.*|${line}|" "$file" && rm -f "$file.bak"
    ok ".asdfrc: updated $key"
  else
    printf '%s\n' "$line" >> "$file"
    ok ".asdfrc: set $key"
  fi
}

# --------------------------------------------------------------------------
# Downloads + integrity
# --------------------------------------------------------------------------
# verify_sha256 FILE EXPECTED
verify_sha256() {
  local file="$1" expected="$2" actual=""
  if [ "${SKIP_CHECKSUM:-0}" = "1" ]; then warn "SKIP_CHECKSUM=1 — not verifying ${file##*/}"; return 0; fi
  if [ -z "$expected" ]; then
    warn "no checksum pinned for ${file##*/} — skipping verification (set it in versions.env)"
    return 0
  fi
  if have sha256sum; then actual="$(sha256sum "$file" | awk '{print $1}')"
  elif have shasum; then actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else warn "no sha256 tool available — cannot verify ${file##*/}"; return 0
  fi
  if [ "$actual" != "$expected" ]; then
    die "checksum mismatch for ${file##*/}: expected $expected, got $actual"
  fi
  ok "checksum verified: ${file##*/}"
}

# download URL DEST [SHA256]
download() {
  local url="$1" dest="$2" sha="${3:-}"
  if is_dry_run; then
    printf '   %s[dry-run]%s download %s -> %s\n' "$_c_dim" "$_c_reset" "$url" "$dest" >&2
    return 0
  fi
  log "downloading ${url##*/}"
  curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url"
  verify_sha256 "$dest" "$sha"
}

# --------------------------------------------------------------------------
# asdf
# --------------------------------------------------------------------------
# Put asdf + its shims on PATH for the remainder of THIS process (no sourcing
# of the user rc file — that broke the zsh flow, see SPEC.md B2/B3).
ensure_asdf_env() {
  export ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
  mkdir -p "$ASDF_DATA_DIR"
  case ":$PATH:" in
    *":$ASDF_DATA_DIR/shims:"*) ;;
    *) export PATH="$ASDF_DATA_DIR/shims:$PATH" ;;
  esac
}

# asdf_install_tool PLUGIN VERSION
#   - install the pinned version if it is not already built
#     (this is the upgrade path: a bumped pin on re-run gets installed)
#   - `asdf plugin update` first, so a freshly-released pinned version resolves
#   - always (re)assert the global pin, so the active version moves to it
asdf_install_tool() {
  local plugin="$1" version="$2" active
  if is_dry_run; then
    printf '   %s[dry-run]%s asdf %s %s\n' "$_c_dim" "$_c_reset" "$plugin" "$version" >&2
    return 0
  fi
  asdf plugin add "$plugin" 2>/dev/null || true
  if asdf list "$plugin" 2>/dev/null | tr -d ' *' | grep -qxF "$version"; then
    log "asdf: $plugin $version already installed"
  else
    # `asdf current` exits non-zero (1 or 126) when the plugin has no version
    # configured yet — never let that abort us; just skip the nicer message.
    active="$(_asdf_active "$plugin")"
    if [ -n "$active" ] && [ "$active" != "$version" ]; then
      step "asdf: upgrade $plugin $active -> $version"
    else
      step "asdf: install $plugin $version"
    fi
    asdf plugin update "$plugin" 2>/dev/null || true
    asdf install "$plugin" "$version"
  fi
  asdf set -u "$plugin" "$version"
  active="$(_asdf_active "$plugin")"
  [ -n "$active" ] && log "asdf: $plugin now $active"
}

# _asdf_active PLUGIN -> the active version, or "" if none / not resolvable.
_asdf_active() {
  asdf current "$1" 2>/dev/null \
    | awk -v p="$1" '$1==p && $2 ~ /[0-9]/ {print $2; exit}' || true
}

# Arm the error trap now that _on_err is defined.
trap '_on_err $LINENO' ERR
