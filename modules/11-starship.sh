#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing Starship prompt"
export PATH="$HOME/.local/bin:$PATH"

# A standalone Starship install also migrates an existing Powerlevel10k setup.
# The Zsh module backs up the old configuration before replacing it.
if [ -e "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ] ||
   [ -e "$HOME/.p10k.zsh" ] ||
   [ -e "$HOME/.p10k.zsh.zwc" ] ||
   grep -Eqi 'powerlevel10k|p10k|FEDORA_PROMPT_ENGINE' \
     "$HOME/.zshrc" "$HOME/.zshenv" 2>/dev/null; then
  warn "Powerlevel10k configuration detected; migrating Zsh to Starship."
  "$ROOT/modules/09-zsh.sh"
fi

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
  backup="$HOME/.config/starship.toml.bak.$(date +%Y%m%d-%H%M%S)"
  log "Backing up existing Starship configuration to $backup"
  cp -f "$HOME/.config/starship.toml" "$backup"
fi
cp -f "$ROOT/config/starship/starship.toml" "$HOME/.config/starship.toml"
cp -f "$ROOT/config/starship/starship-compact.toml" "$HOME/.config/starship-compact.toml"

mkdir -p "$HOME/.config/zsh"
cp -f "$ROOT/config/zsh/starship-adaptive.zsh" \
  "$HOME/.config/zsh/starship-adaptive.zsh"

adaptive_source='[[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/starship-adaptive.zsh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/starship-adaptive.zsh"'
if [ -f "$HOME/.zshrc" ] && ! grep -Fqx "$adaptive_source" "$HOME/.zshrc"; then
  printf '\n%s\n' "$adaptive_source" >> "$HOME/.zshrc"
fi

starship --version

echo "Starship installed with adaptive full and compact configurations."
