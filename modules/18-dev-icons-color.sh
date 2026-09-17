#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/fedora-setup/dev-icons"
BASE_ROOT="$CACHE_HOME/base"
RESOLVED="$CACHE_HOME/resolved.tsv"
ICON_ROOT="$DATA_HOME/icons/hicolor/scalable/mimetypes"
STYLE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fedora-setup"
STYLE_FILE="$STYLE_DIR/dev-icons-style"

ensure_base_icons() {
  if [ ! -s "$RESOLVED" ] || [ ! -d "$BASE_ROOT" ]; then
    log "Base developer icons are not installed yet"
    bash "$ROOT/modules/17-dev-icons.sh"
  fi
}

apply_style() {
  local style="$1"
  local custom_color="${2:-}"
  local count=0

  mkdir -p "$ICON_ROOT" "$STYLE_DIR"

  while IFS=$'\t' read -r mime glyph code accent; do
    [ -n "$mime" ] || continue
    icon_name="${mime//\//-}"
    base="$BASE_ROOT/$icon_name.svg"
    target="$ICON_ROOT/$icon_name.svg"
    symbolic="$ICON_ROOT/$icon_name-symbolic.svg"
    [ -f "$base" ] || continue

    case "$style" in
      monochrome) color="#5E5E5E" ;;
      brand)      color="${accent:-#5E5E5E}" ;;
      custom)     color="$custom_color" ;;
      *) err "Unknown developer icon style: $style"; return 1 ;;
    esac

    sed -E "0,/<svg /s//<svg style=\"fill:${color}\" /" "$base" > "$target"
    cp "$target" "$symbolic"
    count=$((count + 1))
  done < "$RESOLVED"

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
  fi

  if [ "$style" = custom ]; then
    printf 'custom:%s\n' "$custom_color" > "$STYLE_FILE"
  else
    printf '%s\n' "$style" > "$STYLE_FILE"
  fi

  ok "Applied '$style' style to $count developer MIME icons"
}

valid_hex_color() {
  [[ "$1" =~ ^#[0-9A-Fa-f]{6}$ ]]
}

choose_style() {
  local current="monochrome"
  [ -f "$STYLE_FILE" ] && current="$(cat "$STYLE_FILE")"

  echo
  echo "Developer icon color style"
  echo "Current: $current"
  echo
  echo "  1) Monochrome — GNOME-like neutral icons"
  echo "  2) Brand colors — C#, Python, Docker, Git, etc. use individual accents"
  echo "  3) Custom color — one color for every developer icon"
  echo "  4) Keep current style"
  echo

  local choice
  read -r -p "Choose [1-4]: " choice
  case "$choice" in
    1) apply_style monochrome ;;
    2) apply_style brand ;;
    3)
      local color
      while true; do
        read -r -p "Color (#RRGGBB): " color
        if valid_hex_color "$color"; then
          apply_style custom "$color"
          break
        fi
        echo "Use a six-digit hex color, for example #3584E4."
      done
      ;;
    4|'') ok "Keeping current developer icon style: $current" ;;
    *) err "Invalid choice: $choice"; return 1 ;;
  esac
}

ensure_base_icons

# Non-interactive use is supported for scripts and repeated setup runs:
#   DEV_ICON_STYLE=brand ./install.sh dev-icons-color
#   DEV_ICON_STYLE=monochrome ./install.sh dev-icons-color
#   DEV_ICON_STYLE=custom DEV_ICON_COLOR=#3584E4 ./install.sh dev-icons-color
style="${DEV_ICON_STYLE:-}"
if [ -n "$style" ]; then
  case "$style" in
    monochrome|brand) apply_style "$style" ;;
    custom)
      color="${DEV_ICON_COLOR:-}"
      valid_hex_color "$color" || { err "DEV_ICON_COLOR must be #RRGGBB for custom style."; exit 1; }
      apply_style custom "$color"
      ;;
    *) err "DEV_ICON_STYLE must be monochrome, brand, or custom."; exit 1 ;;
  esac
elif [ -t 0 ]; then
  choose_style
else
  # The full bootstrap deliberately remains non-interactive. Directly running
  # this module (or using DEV_ICON_STYLE) is how the user opts into colors.
  current="monochrome"
  [ -f "$STYLE_FILE" ] && current="$(cat "$STYLE_FILE")"
  ok "Developer icon color style unchanged: $current"
  echo "Run './install.sh dev-icons-color' in a terminal to choose a style,"
  echo "or set DEV_ICON_STYLE=brand|monochrome|custom explicitly."
fi

echo "You can run this module again whenever you want to switch styles."
