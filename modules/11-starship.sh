#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing Starship prompt"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v starship >/dev/null 2>&1; then
  if dnf -q info starship >/dev/null 2>&1; then
    sudo dnf install -y starship
  else
    warn "Fedora package 'starship' is unavailable; using the official user-local installer."
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
  fi
fi

mkdir -p "$HOME/.config"
if [ -f "$HOME/.config/starship.toml" ]; then
  warn "Existing ~/.config/starship.toml kept unchanged. Template is available at config/starship/starship.toml."
else
  cp "$ROOT/config/starship/starship.toml" "$HOME/.config/starship.toml"
fi

starship --version

echo "Starship installed and selected as the default Zsh prompt."
