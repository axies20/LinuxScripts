#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing base tools and applications"
sudo dnf install -y \
  git gedit curl wget vim nano net-tools zip unzip tar xz jq ripgrep fd-find fzf bat tmux \
  git-delta code yq openssl-devel libicu gnome-tweaks steam fastfetch java-latest-openjdk \
  ca-certificates p11-kit p11-kit-trust nss-tools openssl fontconfig powerline-fonts dnf-plugins-core \
  kernel-devel kernel-headers gcc make flatpak 1password

install_if_available eza exa

log "Refreshing CA trust"
sudo update-ca-trust
sudo mkdir -p /etc/ssl/certs
sudo ln -sfn /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

log "Installing Brave"
if ! command -v brave-browser >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
  curl -fsS https://dl.brave.com/install.sh | sh
else
  echo "Brave is already installed."
fi
