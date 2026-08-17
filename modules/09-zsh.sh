#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing Zsh + Oh My Zsh"
sudo dnf install -y zsh git curl util-linux-user

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no \
  CHSH=no \
  KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_if_missing() { [ -d "$2" ] || git clone ${3:-} "$1" "$2"; }
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
clone_if_missing https://github.com/marlonrichert/zsh-autocomplete "$ZSH_CUSTOM/plugins/zsh-autocomplete" "--depth=1"

if [ -f "$HOME/.zshrc" ]; then
  cp -f "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
fi

cat > "$HOME/.zshenv" <<'EOF_ZENV'
export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.dotnet/tools:$PATH"
export ASPIRE_CONTAINER_RUNTIME=podman
export SSL_CERT_DIR="${SSL_CERT_DIR:+$SSL_CERT_DIR:}/etc/pki/tls/certs:$HOME/.aspnet/dev-certs/trust"
export FEDORA_PROMPT_ENGINE="${FEDORA_PROMPT_ENGINE:-starship}"
EOF_ZENV

cat > "$HOME/.zshrc" <<'EOF_ZRC'
export ZSH="$HOME/.oh-my-zsh"

# Prompt engine: starship (default) or powerlevel10k (optional).
FEDORA_PROMPT_ENGINE="${FEDORA_PROMPT_ENGINE:-starship}"
if [[ "$FEDORA_PROMPT_ENGINE" == "powerlevel10k" && -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME=""
fi

plugins=(
  git git-auto-fetch npm sudo podman dotnet pip kubectl aliases colorize command-not-found
  colored-man-pages zsh-completions zsh-autocomplete zsh-autosuggestions zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

if [[ "$FEDORA_PROMPT_ENGINE" == "starship" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
elif [[ "$FEDORA_PROMPT_ENGINE" == "powerlevel10k" ]]; then
  [[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
fi

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=$HOME/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
bindkey '^ ' autosuggest-accept

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
EOF_ZRC

zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" != "$zsh_path" ]; then
  log "Setting Zsh as the default shell for $USER"
  sudo usermod --shell "$zsh_path" "$USER"
fi

echo "Zsh configured. Starship is the default prompt engine and is installed by the next module."
