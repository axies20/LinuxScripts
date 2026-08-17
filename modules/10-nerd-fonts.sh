#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

log "Installing Nerd Fonts"

FONT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NerdFonts"
mkdir -p "$FONT_ROOT"

# Override when desired, for example:
# NERD_FONTS="JetBrainsMono FiraCode" ./install.sh nerd-fonts
NERD_FONTS="${NERD_FONTS:-JetBrainsMono FiraCode Meslo}"
read -r -a fonts <<< "$NERD_FONTS"

font_family_for_asset() {
  case "$1" in
    JetBrainsMono) printf '%s\n' 'JetBrainsMono Nerd Font' ;;
    FiraCode)       printf '%s\n' 'FiraCode Nerd Font' ;;
    Meslo)          printf '%s\n' 'MesloLGS NF' ;;
    *)              printf '%s\n' "$1" ;;
  esac
}

install_font() {
  local asset="$1"
  local family
  family="$(font_family_for_asset "$asset")"
  local target="$FONT_ROOT/$asset"

  if command -v fc-list >/dev/null 2>&1 && fc-list : family 2>/dev/null | grep -Fqi "$family"; then
    ok "$family is already installed; skipping"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  local archive="$tmp/$asset.zip"
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$asset.zip"

  log "Downloading $family"
  if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
      -o "$archive" "$url"; then
    rm -rf "$tmp"
    err "Failed to download Nerd Font asset: $asset"
    return 1
  fi

  rm -rf "$target"
  mkdir -p "$target"
  unzip -q -o "$archive" -d "$target"

  # Keep only actual font files. Release archives may contain docs/licenses.
  find "$target" -type f ! \( -iname '*.ttf' -o -iname '*.otf' \) -delete
  find "$target" -type d -empty -delete || true
  rm -rf "$tmp"

  ok "$family installed"
}

for font in "${fonts[@]}"; do
  install_font "$font"
done

if command -v fc-cache >/dev/null 2>&1; then
  log "Refreshing font cache"
  fc-cache -f "$FONT_ROOT" >/dev/null
else
  warn "fc-cache is unavailable. Install fontconfig and refresh the font cache manually."
fi

log "Installed Nerd Font families"
if command -v fc-list >/dev/null 2>&1; then
  for font in "${fonts[@]}"; do
    family="$(font_family_for_asset "$font")"
    if fc-list : family 2>/dev/null | grep -Fqi "$family"; then
      printf '  ✓ %s\n' "$family"
    else
      printf '  ? %s (font cache may need a new login)\n' "$family"
    fi
  done
fi

echo "Choose a Nerd Font in your terminal profile. MesloLGS NF is recommended for Powerlevel10k."
