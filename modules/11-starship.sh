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

# The official installer installs the latest release and updates an existing
# binary when rerun. A user-local binary takes precedence over an older Fedora
# package because ~/.local/bin is prepended to PATH above.
mkdir -p "$HOME/.local/bin"
starship_tmp="$(mktemp -d)"
starship_installer="$starship_tmp/install.sh"

if curl -fsSL https://starship.rs/install.sh -o "$starship_installer"; then
  sh "$starship_installer" --yes --bin-dir "$HOME/.local/bin"
elif command -v starship >/dev/null 2>&1; then
  warn "Could not check for a Starship update; keeping $(starship --version | head -n1)."
else
  rm -rf -- "$starship_tmp"
  err "Could not download the official Starship installer."
  exit 1
fi

rm -rf -- "$starship_tmp"
hash -r

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
