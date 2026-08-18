#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

require_fedora
require_sudo

log "Installing GNOME tools"

install_packages_if_missing \
  gnome-tweaks \
  jq \
  curl \
  python3

if ! command -v gnome-extensions >/dev/null 2>&1; then
  warn "gnome-extensions is unavailable; skipping GNOME extensions."
  exit 0
fi

if ! command -v gnome-shell >/dev/null 2>&1; then
  warn "gnome-shell is unavailable; skipping GNOME extensions."
  exit 0
fi

shell_version="$(gnome-shell --version)"
shell_major="$(
  printf '%s\n' "$shell_version" |
    grep -oE '[0-9]+' |
    head -1
)"

log "Detected $shell_version"
echo "GNOME Shell major version: $shell_major"

extensions=(
  blur-my-shell@aunetx
  dash-to-dock@micxgx.gmail.com
  gtk4-ding@smedius.gitlab.com
  clipboard-indicator@tudmotu.com
  osd-volume-number@deminder
  search-light@icedman.github.com
  fullscreen-avoider@noobsai.github.com
  gnome-fuzzy-app-search@gnome-shell-extensions.Czarlie.gitlab.com
  gamebar-overlay@dekotale.github.io
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

installed_extensions=()
existing_extensions=()
skipped_extensions=()
failed_extensions=()

for extension in "${extensions[@]}"; do
  log "GNOME extension: $extension"

  extension_dir="$HOME/.local/share/gnome-shell/extensions/$extension"
  if [ -d "$extension_dir" ]; then
    ok "$extension is already installed; skipping download"
    existing_extensions+=("$extension")
    continue
  fi

  json="$(
    curl \
      -fLsS \
      --retry 3 \
      --retry-delay 2 \
      --connect-timeout 15 \
      --get \
      --data-urlencode "search=$extension" \
      "https://extensions.gnome.org/extension-query/" \
      2>/dev/null || true
  )"

  if [ -z "$json" ]; then
    warn "Could not query extensions.gnome.org for $extension"
    failed_extensions+=("$extension")
    continue
  fi

  tag="$(
    jq -r \
      --arg uuid "$extension" \
      --arg shell "$shell_major" \
      '
        .extensions[]?
        | select(.uuid == $uuid)
        | .shell_version_map[$shell].pk // empty
      ' \
      <<< "$json" 2>/dev/null |
      head -1 || true
  )"

  if [ -z "$tag" ]; then
    warn "No GNOME $shell_major compatible build for $extension; skipping."
    skipped_extensions+=("$extension")
    continue
  fi

  zip="$tmp/$extension.zip"

  log "Downloading version tag $tag"

  if ! curl \
      -fL \
      --retry 3 \
      --retry-delay 2 \
      --connect-timeout 15 \
      -o "$zip" \
      "https://extensions.gnome.org/download-extension/${extension}.shell-extension.zip?version_tag=${tag}"
  then
    warn "Could not download $extension"
    failed_extensions+=("$extension")
    continue
  fi

  log "Installing $extension"

  if ! gnome-extensions install --force "$zip"; then
    warn "gnome-extensions could not install $extension"
    failed_extensions+=("$extension")
    continue
  fi

  if [ ! -d "$extension_dir" ]; then
    warn "$extension was not found in $extension_dir after installation"
    failed_extensions+=("$extension")
    continue
  fi

  ok "$extension installed"
  installed_extensions+=("$extension")
done

# GNOME Shell will discover newly installed extensions on the next session.
# Add both new and pre-existing UUIDs to the enabled list without reinstalling.
extensions_to_enable=("${installed_extensions[@]}" "${existing_extensions[@]}")
if [ "${#extensions_to_enable[@]}" -gt 0 ]; then
  log "Ensuring GNOME extensions are enabled on the next session"

  current="$(
    gsettings get org.gnome.shell enabled-extensions 2>/dev/null ||
      printf '[]'
  )"

  new_list="$(
    python3 - "$current" "${extensions_to_enable[@]}" <<'PY'
import ast
import sys

try:
    extensions = ast.literal_eval(sys.argv[1])
except Exception:
    extensions = []

for extension in sys.argv[2:]:
    if extension not in extensions:
        extensions.append(extension)

print(
    "[" +
    ", ".join(repr(extension) for extension in extensions) +
    "]"
)
PY
  )"

  gsettings set \
    org.gnome.shell \
    enabled-extensions \
    "$new_list"

  # Make sure the global user-extension switch isn't disabled.
  if gsettings writable \
      org.gnome.shell \
      disable-user-extensions >/dev/null 2>&1
  then
    gsettings set \
      org.gnome.shell \
      disable-user-extensions \
      false
  fi
fi

echo
echo "GNOME extension installation summary"
echo "------------------------------------"

printf 'Installed: %d\n' "${#installed_extensions[@]}"
for extension in "${installed_extensions[@]}"; do
  printf '  ✓ %s\n' "$extension"
done

printf '\nAlready installed: %d\n' "${#existing_extensions[@]}"
for extension in "${existing_extensions[@]}"; do
  printf '  = %s\n' "$extension"
done

printf '\nSkipped (not compatible with GNOME %s): %d\n' \
  "$shell_major" \
  "${#skipped_extensions[@]}"

for extension in "${skipped_extensions[@]}"; do
  printf '  - %s\n' "$extension"
done

printf '\nFailed: %d\n' "${#failed_extensions[@]}"
for extension in "${failed_extensions[@]}"; do
  printf '  ✗ %s\n' "$extension"
done

echo
echo "New GNOME Shell extensions are loaded on the next session."
echo "Log out and log back in after the setup finishes."
