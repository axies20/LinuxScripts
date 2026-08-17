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

log "Installed ${#mime_sources[@]} MIME definition file(s)"
"$ROOT/diagnostics/check-mime.sh" || true
