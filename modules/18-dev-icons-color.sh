#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STYLE_DIR="$CONFIG_HOME/fedora-setup"
STYLE_FILE="$STYLE_DIR/dev-icons-style"
WORKER="$HOME/.local/bin/dev-mime-icons"

ensure_resolver() {
  if [ ! -x "$WORKER" ]; then
    log "Developer icon resolver is not installed yet"
    bash "$ROOT/modules/17-dev-icons.sh"
  fi
}

valid_hex_color() {
  [[ "$1" =~ ^#[0-9A-Fa-f]{6}$ ]]
}

apply_style() {
  local style="$1"
  local color="${2:-}"
  mkdir -p "$STYLE_DIR"

  case "$style" in
    monochrome|brand) printf '%s\n' "$style" > "$STYLE_FILE" ;;
    custom)
      valid_hex_color "$color" || { err "Custom color must be #RRGGBB."; return 1; }
      printf 'custom:%s\n' "$color" > "$STYLE_FILE"
      ;;
    *) err "Unknown developer icon style: $style"; return 1 ;;
  esac

  "$WORKER" reconcile
  ok "Applied '$style' developer icon style"
}

choose_style() {
  local current="monochrome"
  [ -f "$STYLE_FILE" ] && current="$(cat "$STYLE_FILE")"

  echo
  echo "Developer icon color style"
  echo "Current: $current"
  echo
  echo "  1) Monochrome — GNOME-like neutral icons"
  echo "  2) Brand colors — use known technology accents when available"
  echo "  3) Custom color — one color for generated Nerd Font icons"
  echo "  4) Keep current style"
  echo

  local choice color
  read -r -p "Choose [1-4]: " choice
  case "$choice" in
    1) apply_style monochrome ;;
    2) apply_style brand ;;
    3)
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

ensure_resolver

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
  current="monochrome"
  [ -f "$STYLE_FILE" ] && current="$(cat "$STYLE_FILE")"
  ok "Developer icon color style unchanged: $current"
  echo "Run './install.sh dev-icons-color' in a terminal to choose a style,"
  echo "or set DEV_ICON_STYLE=brand|monochrome|custom explicitly."
fi
