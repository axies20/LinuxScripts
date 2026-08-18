#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Configuring Flathub"
install_packages_if_missing flatpak
if ! flatpak remotes --system --columns=name | grep -qx flathub; then
  sudo flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
sudo flatpak remote-modify --system --gpg-verify=true flathub

apps=(
  com.mattjakeman.ExtensionManager
  org.telegram.desktop
  org.qbittorrent.qBittorrent
  com.vysp3r.ProtonPlus
  com.heroicgameslauncher.hgl
  net.davidotek.pupgui2
  app.drey.Damask
  org.gnome.FileRoller
  com.github.tchx84.Flatseal
  org.pipewire.Helvum
)

log "Installing Flatpak applications"
for app in "${apps[@]}"; do
  if flatpak info --system "$app" >/dev/null 2>&1; then
    ok "$app is already installed; skipping"
  else
    sudo flatpak install --system -y --noninteractive flathub "$app" || warn "Could not install Flatpak $app"
  fi
done
