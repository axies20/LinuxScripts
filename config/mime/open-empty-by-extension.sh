#!/usr/bin/env bash
set -u

if [ "$#" -eq 0 ]; then
  exit 0
fi

tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT
launcher="${EMPTY_FILE_LAUNCHER:-gtk-launch}"

for target in "$@"; do
  [ -e "$target" ] || continue

  # A one-byte probe bypasses GLib's application/x-zerosize special case.
  # The original basename makes shared-mime-info apply the same glob rule.
  probe="$tmp/$(basename -- "$target")"
  printf '\n' > "$probe"
  mime="$(xdg-mime query filetype "$probe" 2>/dev/null || true)"
  desktop=""
  if [ -n "$mime" ] && [ "$mime" != application/x-zerosize ]; then
    desktop="$(xdg-mime query default "$mime" 2>/dev/null || true)"
  fi

  if [ -z "$desktop" ]; then
    desktop="$(xdg-mime query default text/plain 2>/dev/null || true)"
  fi
  desktop="${desktop:-org.gnome.TextEditor.desktop}"

  if ! "$launcher" "$desktop" "$target"; then
    "$launcher" org.gnome.TextEditor.desktop "$target" 2>/dev/null || true
  fi
done
