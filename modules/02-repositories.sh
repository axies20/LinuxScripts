#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

fedora_ver="$(rpm -E %fedora)"
log "Enabling RPM Fusion"
repo_changed=0
rpmfusion_urls=()
rpm -q rpmfusion-free-release >/dev/null 2>&1 ||
  rpmfusion_urls+=("https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm")
rpm -q rpmfusion-nonfree-release >/dev/null 2>&1 ||
  rpmfusion_urls+=("https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm")

if [ "${#rpmfusion_urls[@]}" -gt 0 ]; then
  sudo dnf install -y "${rpmfusion_urls[@]}"
  repo_changed=1
else
  ok "RPM Fusion repositories are already installed; skipping"
fi

log "Configuring 1Password repository"
if [ ! -f /etc/yum.repos.d/1password.repo ]; then
  sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
  sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
  repo_changed=1
else
  ok "1Password repository is already configured; skipping"
fi

log "Configuring Visual Studio Code repository"
if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
  repo_changed=1
else
  ok "Visual Studio Code repository is already configured; skipping"
fi

if [ "$repo_changed" -eq 1 ]; then
  sudo dnf makecache -y
else
  ok "Repository configuration is unchanged; metadata refresh skipped"
fi
