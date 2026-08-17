#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

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
  10-nerd-fonts
  11-starship
  12-gnome
  13-nautilus
  14-flatpak
  15-nvidia
  16-mime
  17-finalize
)

if [ "$#" -gt 0 ]; then
  modules=("$@")
fi

# Authenticate once for the whole installation. Child modules receive
# FEDORA_SETUP_SUDO_READY=1 and therefore never ask for sudo themselves.
if ! command -v sudo >/dev/null 2>&1; then
  err "sudo is not installed."
  exit 1
fi

echo "Fedora Setup will now run ${#modules[@]} module(s) automatically."
echo "No Enter key is required between modules."
echo

if ! sudo -n true >/dev/null 2>&1; then
  echo "Administrator access is required for system changes."
  echo "sudo may ask for your password once now."
  sudo -v
fi

export FEDORA_SETUP_SUDO_READY=1

# Keep the sudo timestamp alive while the installer runs so a long download or
# build does not cause a second password prompt later.
(
  while true; do
    sudo -n true >/dev/null 2>&1 || exit 0
    sleep 50
  done
) &
SUDO_KEEPALIVE_PID=$!

cleanup() {
  kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

for module in "${modules[@]}"; do
  name="${module%.sh}"
  script="$ROOT/modules/$name.sh"

  if [ ! -f "$script" ]; then
    err "Module not found: $module"
    exit 1
  fi

  log "Running $name"
  bash "$script"
  ok "$name completed — continuing automatically"
done

log "Fedora setup finished"
echo "No automatic reboot is performed."
echo "Log out/in (or reboot) to apply shell, GNOME, NVIDIA/kernel and session changes."
