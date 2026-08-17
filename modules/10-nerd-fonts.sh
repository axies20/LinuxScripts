#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing Nerd Fonts"

sudo dnf install -y fontconfig curl tar xz unzip

FONT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/NerdFonts"
mkdir -p "$FONT_ROOT"

# Space-separated Nerd Fonts release asset names. Override if desired, e.g.:
#   NERD_FONTS="JetBrainsMono FiraCode" ./install.sh 10-nerd-fonts
read -r -a fonts <<< "${NERD_FONTS:-JetBrainsMono FiraCode Meslo}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

copy_font_files() {
  local source_dir="$1" destination="$2"
  while IFS= read -r -d '' font_file; do
    cp -f "$font_file" "$destination/"
  done < <(find "$source_dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
}

install_font() {
  local font="$1"
  local destination="$FONT_ROOT/$font"
  local extract_dir="$tmp_dir/$font"
  local xz_archive="$tmp_dir/$font.tar.xz"
  local zip_archive="$tmp_dir/$font.zip"
  local xz_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.tar.xz"
  local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.zip"

  if find "$destination" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print -quit 2>/dev/null | grep -q .; then
    echo "$font Nerd Font is already installed by fedora-setup; skipping."
    return 0
  fi

  log "Installing $font Nerd Font"
  mkdir -p "$destination" "$extract_dir"

  # Nerd Fonts publishes compact tar.xz release archives. Fall back to ZIP if
  # a particular family/release does not provide the XZ asset.
  if curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
      -o "$xz_archive" "$xz_url"; then
    tar -xJf "$xz_archive" -C "$extract_dir"
  else
    warn "$font.tar.xz is unavailable; falling back to ZIP."
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
      -o "$zip_archive" "$zip_url"
    unzip -q "$zip_archive" -d "$extract_dir"
  fi

  copy_font_files "$extract_dir" "$destination"

  if ! find "$destination" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print -quit | grep -q .; then
    err "No font files were found in the $font Nerd Font archive."
    return 1
  fi
}

for font in "${fonts[@]}"; do
  install_font "$font"
done

log "Refreshing the user font cache"
fc-cache -f "$FONT_ROOT"

echo
echo "Installed Nerd Font families:"
fc-list : family | grep -Ei 'JetBrainsMono Nerd Font|FiraCode Nerd Font|Meslo.*Nerd Font' | sort -u | head -n 30 || true

echo
echo "JetBrainsMono Nerd Font is the recommended default for the terminal/IDE console."
echo "Select it in your terminal profile; the installer does not change GNOME UI fonts."
