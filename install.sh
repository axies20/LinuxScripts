#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"
require_fedora
require_sudo

modules=(
  01-system
  02-repositories
  03-packages
  04-codecs
  05-podman
  06-dotnet
  07-aspire
  08-node-codex
  09-zsh
  10-starship
  11-gnome
  12-nautilus
  13-flatpak
  14-nvidia
  15-mime
  16-finalize
)

if [ "$#" -gt 0 ]; then
  modules=("$@")
fi

for module in "${modules[@]}"; do
  script="$ROOT/modules/${module%.sh}.sh"
  if [ ! -f "$script" ]; then
    err "Module not found: $module"
    exit 1
  fi
  log "Running ${module%.sh}"
  bash "$script"
done

log "Fedora setup finished"
echo "Log out/in (or reboot) to apply shell, GNOME, NVIDIA/kernel and session changes."
