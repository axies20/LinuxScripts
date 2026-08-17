#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing Nautilus extension support"
sudo dnf install -y nautilus-python nautilus-extensions
install_if_available nautilus-gtkhash gtkhash

mkdir -p "$HOME/Templates"
[ -e "$HOME/Templates/Text File.txt" ] || touch "$HOME/Templates/Text File.txt"
mkdir -p "$HOME/.themes" "$HOME/.icons" "$HOME/.local/share/themes" "$HOME/.local/share/icons"
