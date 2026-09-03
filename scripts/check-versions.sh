#!/usr/bin/env bash
# check-versions.sh — compare src/versions.env against upstream "latest".
# Best-effort and network-dependent: a lookup that fails prints "skip", never
# errors. Prints "OUTDATED <tool>: ..." when a newer version is available.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
# shellcheck disable=SC1091
. src/versions.env

status=0
J() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)" 2>/dev/null; }

report() {
  # report NAME PINNED LATEST
  local name="$1" pinned="$2" latest="$3"
  if [ -z "$latest" ]; then
    printf 'skip     %-10s (upstream lookup failed)\n' "$name"
    return
  fi
  if [ "$pinned" = "$latest" ]; then
    printf 'ok       %-10s %s\n' "$name" "$pinned"
  else
    printf 'OUTDATED %-10s pinned %s, latest %s\n' "$name" "$pinned" "$latest"
    status=1
  fi
}

gh_latest() { # owner/repo -> tag without leading v
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | J "d['tag_name']" | sed 's/^v//'
}

# --- nodejs: newest LTS line, newest patch --------------------------------
node_latest="$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null \
  | python3 -c "import sys,json
d=json.load(sys.stdin)
lts=[x for x in d if x['lts']]
print(lts[0]['version'].lstrip('v')) if lts else print('')" 2>/dev/null)"
report nodejs "$NODEJS_VERSION" "$node_latest"

# --- python: latest patch of the pinned minor ----------------------------
py_minor="${PYTHON_VERSION%.*}"
py_latest="$(curl -fsSL "https://endoflife.date/api/python/${py_minor}.json" 2>/dev/null | J "d['latest']")"
report python "$PYTHON_VERSION" "$py_latest"

# --- go ----------------------------------------------------------------
go_latest="$(curl -fsSL 'https://go.dev/dl/?mode=json' 2>/dev/null | J "d[0]['version']" | sed 's/^go//')"
report golang "$GOLANG_VERSION" "$go_latest"

# --- terraform / helm / sops / asdf (GitHub) --------------------------
report terraform "$TERRAFORM_VERSION" "$(gh_latest hashicorp/terraform)"
report helm      "$HELM_VERSION"      "$(gh_latest helm/helm)"
report sops      "$SOPS_VERSION"      "$(gh_latest getsops/sops)"
report asdf      "$ASDF_VERSION"      "$(gh_latest asdf-vm/asdf)"

# --- kubectl ---------------------------------------------------------------
report kubectl "$KUBECTL_VERSION" "$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null | sed 's/^v//')"

# --- ruby ----------------------------------------------------------------
ruby_minor="${RUBY_VERSION%.*}"
report ruby "$RUBY_VERSION" "$(curl -fsSL "https://endoflife.date/api/ruby/${ruby_minor}.json" 2>/dev/null | J "d['latest']")"

# --- flutter -----------------------------------------------------------
flutter_latest="$(curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json 2>/dev/null \
  | python3 -c "import sys,json
d=json.load(sys.stdin)
h=d['current_release']['stable']
for r in d['releases']:
    if r['hash']==h: print(r['version'].lstrip('v')+'-stable'); break" 2>/dev/null)"
report flutter "$FLUTTER_VERSION" "$flutter_latest"

echo
echo "java (Temurin) and the Android SDK builds are checked manually — see SPEC.md."
exit "$status"
