#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Disabling HDA audio power save"
line='options snd_hda_intel power_save=0 power_save_controller=N'
conf='/etc/modprobe.d/snd_hda_intel.conf'
sudo touch "$conf"
grep -qxF "$line" "$conf" || printf '%s\n' "$line" | sudo tee -a "$conf" >/dev/null

if command -v gsettings >/dev/null 2>&1; then
  log "Setting GNOME volume step to 2"
  gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2 || warn "Could not set volume-step outside a GNOME session."
fi

log "Updating Fedora"
sudo dnf upgrade --refresh -y
