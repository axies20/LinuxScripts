#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

if ! command -v update-mime-database >/dev/null 2>&1; then
  sudo dnf install -y shared-mime-info
fi

mime_home="${XDG_DATA_HOME:-$HOME/.local/share}/mime"
packages="$mime_home/packages"
mkdir -p "$packages"

log "Installing developer MIME catalog"
# Remove stale files from older versions of this setup before copying the
# current split catalog. This only touches files owned by fedora-setup.
rm -f "$packages"/fedora-setup-*.xml

for source in "$ROOT"/config/mime/*.xml; do
  name="$(basename "$source")"
  install -m 0644 "$source" "$packages/fedora-setup-$name"
done

update-mime-database "$mime_home"

log "MIME database updated"
log "No default editor is forced. In Nautilus use Open With → choose an application → Set as Default."
"$ROOT/diagnostics/check-mime.sh" || true
