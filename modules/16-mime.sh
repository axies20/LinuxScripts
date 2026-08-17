#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

if ! command -v update-mime-database >/dev/null 2>&1; then
  require_sudo
  sudo dnf install -y shared-mime-info
fi

mime_home="${XDG_DATA_HOME:-$HOME/.local/share}/mime"
packages="$mime_home/packages"
mkdir -p "$packages"

log "Installing developer and Windows compatibility MIME definitions"

# Remove only files previously installed by this setup so renamed/removed
# definitions don't remain in the user's MIME database.
rm -f "$packages"/fedora-setup-*.xml

shopt -s nullglob
mime_sources=("$ROOT"/config/mime/*.xml)
shopt -u nullglob

if [ "${#mime_sources[@]}" -eq 0 ]; then
  err "No MIME definition files found in $ROOT/config/mime"
  exit 1
fi

for source in "${mime_sources[@]}"; do
  filename="$(basename "$source")"
  install -m 0644 "$source" "$packages/fedora-setup-$filename"
done

update-mime-database "$mime_home"

log "Configuring extension-aware opening for empty files"
helper_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
helper="$helper_dir/fedora-open-empty-by-extension"
desktop="$applications/fedora-open-empty-by-extension.desktop"
mkdir -p "$helper_dir" "$applications" "$config_home"
install -m 0755 "$ROOT/config/mime/open-empty-by-extension.sh" "$helper"

# Desktop Exec quoting is independent from shell quoting. Escape the two
# characters that are special inside a quoted Desktop Entry argument.
desktop_helper="${helper//\\/\\\\}"
desktop_helper="${desktop_helper//\"/\\\"}"
desktop_helper="${desktop_helper//%/%%}"
desktop_helper="${desktop_helper//&/\\&}"
desktop_helper="${desktop_helper//|/\\|}"
sed "s|@HELPER@|$desktop_helper|" \
  "$ROOT/config/mime/open-empty-by-extension.desktop.in" > "$desktop"
chmod 0644 "$desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$applications"
xdg-mime default fedora-open-empty-by-extension.desktop application/x-zerosize

log "Installed ${#mime_sources[@]} MIME definition file(s)"
"$ROOT/diagnostics/check-mime.sh" || true
