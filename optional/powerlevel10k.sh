#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  err "Oh My Zsh is not installed. Run ./install.sh 09-zsh first."
  exit 1
fi

log "Installing optional Powerlevel10k prompt"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

if grep -q '^export FEDORA_PROMPT_ENGINE=' "$HOME/.zshenv" 2>/dev/null; then
  sed -i 's/^export FEDORA_PROMPT_ENGINE=.*/export FEDORA_PROMPT_ENGINE="powerlevel10k"/' "$HOME/.zshenv"
else
  printf '%s\n' 'export FEDORA_PROMPT_ENGINE="powerlevel10k"' >> "$HOME/.zshenv"
fi

cat <<'MSG'
Powerlevel10k installed and selected.
Open a new terminal, then run:
  p10k configure

To switch back to Starship:
  sed -i 's/FEDORA_PROMPT_ENGINE="powerlevel10k"/FEDORA_PROMPT_ENGINE="starship"/' ~/.zshenv
  exec zsh
MSG
