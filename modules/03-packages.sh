#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Checking base tools and applications"
install_packages_if_missing \
  git gh gedit curl wget vim nano net-tools zip unzip tar jq ripgrep fd-find fzf bat tmux \
  git-delta code yq openssl-devel libicu gnome-tweaks steam fastfetch java-latest-openjdk \
  ca-certificates p11-kit p11-kit-trust nss-tools openssl powerline-fonts \
  rsms-inter-vf-fonts rsms-inter-fonts dnf-plugins-core python3-pygments \
  kernel-devel kernel-headers gcc make flatpak 1password

install_if_available eza exa

log "Installing uv and the latest Python"

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
  err "uv installation completed, but 'uv' is not available on PATH."
  exit 1
fi

uv python install --default

log "Refreshing CA trust"
sudo update-ca-trust
sudo mkdir -p /etc/ssl/certs
sudo ln -sfn /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

log "Installing Brave"

if ! command -v brave-browser >/dev/null 2>&1; then
    if [ ! -f /etc/yum.repos.d/brave-browser.repo ]; then
        sudo dnf config-manager addrepo \
            --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    fi

    sudo dnf install -y brave-browser
else
    ok "Brave is already installed; skipping"
fi
