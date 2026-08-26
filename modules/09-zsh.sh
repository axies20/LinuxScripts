#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

if [ "$EUID" -eq 0 ]; then
  err "Do not run this module as root or with sudo."
  echo
  echo "Run it as your normal user:"
  echo "  ./install.sh zsh"
  echo
  echo "The installer will request sudo automatically when required."
  exit 1
fi

require_fedora
require_sudo

log "Installing Zsh + Oh My Zsh"

install_packages_if_missing \
  zsh \
  git \
  curl \
  util-linux-user

# ---------------------------------------------------------------------------
# Remove legacy Powerlevel10k
# ---------------------------------------------------------------------------

log "Removing legacy Powerlevel10k files"

P10K_THEME="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
P10K_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
rm -rf -- \
  "$P10K_THEME" \
  "$HOME/.p10k.zsh" \
  "$HOME/.p10k.zsh.zwc"

if [ -d "$P10K_CACHE_DIR" ]; then
  find "$P10K_CACHE_DIR" -mindepth 1 -maxdepth 1 \
    \( -name 'p10k-*' -o -name 'p10k-instant-prompt-*' \) \
    -exec rm -rf -- {} +
fi

ok "Powerlevel10k files removed"

# ---------------------------------------------------------------------------
# Oh My Zsh
# ---------------------------------------------------------------------------

OH_MY_ZSH="$HOME/.oh-my-zsh"

if [ ! -f "$OH_MY_ZSH/oh-my-zsh.sh" ]; then
  if [ -e "$OH_MY_ZSH" ]; then
    warn "Incomplete Oh My Zsh installation detected; removing it."
    rm -rf "$OH_MY_ZSH"
  fi

  log "Installing Oh My Zsh"

  git clone \
    --depth=1 \
    https://github.com/ohmyzsh/ohmyzsh.git \
    "$OH_MY_ZSH"

  if [ ! -f "$OH_MY_ZSH/oh-my-zsh.sh" ]; then
    err "Oh My Zsh installation failed."
    exit 1
  fi

  ok "Oh My Zsh installed"
else
  ok "Oh My Zsh is already installed; skipping"
fi

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------

ZSH_CUSTOM="${ZSH_CUSTOM:-$OH_MY_ZSH/custom}"

clone_plugin() {
  local url="$1"
  local destination="$2"
  local name="$3"

  if [ -d "$destination/.git" ]; then
    ok "$name is already installed; skipping"
    return 0
  fi

  if [ -e "$destination" ]; then
    warn "Incomplete $name installation detected; removing it."
    rm -rf "$destination"
  fi

  log "Installing $name"

  git clone \
    --depth=1 \
    "$url" \
    "$destination"

  if [ ! -d "$destination/.git" ]; then
    err "$name installation failed."
    return 1
  fi

  ok "$name installed"
}

mkdir -p "$ZSH_CUSTOM/plugins"

clone_plugin \
  "https://github.com/zsh-users/zsh-autosuggestions" \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
  "zsh-autosuggestions"

clone_plugin \
  "https://github.com/zsh-users/zsh-syntax-highlighting" \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
  "zsh-syntax-highlighting"

clone_plugin \
  "https://github.com/zsh-users/zsh-completions" \
  "$ZSH_CUSTOM/plugins/zsh-completions" \
  "zsh-completions"

clone_plugin \
  "https://github.com/marlonrichert/zsh-autocomplete" \
  "$ZSH_CUSTOM/plugins/zsh-autocomplete" \
  "zsh-autocomplete"

# ---------------------------------------------------------------------------
# Zsh runtime data
# ---------------------------------------------------------------------------

ZSH_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"

mkdir -p "$ZSH_DATA_DIR"
touch "$ZSH_DATA_DIR/chpwd-recent-dirs"

# ---------------------------------------------------------------------------
# Backup existing configuration
# ---------------------------------------------------------------------------

if [ -f "$HOME/.zshrc" ]; then
  backup="$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)"

  log "Backing up existing .zshrc to $backup"
  cp -f "$HOME/.zshrc" "$backup"
fi

if [ -f "$HOME/.zshenv" ]; then
  backup="$HOME/.zshenv.bak.$(date +%Y%m%d-%H%M%S)"

  log "Backing up existing .zshenv to $backup"
  cp -f "$HOME/.zshenv" "$backup"
fi

# ---------------------------------------------------------------------------
# Zsh environment
# ---------------------------------------------------------------------------

cat > "$HOME/.zshenv" <<'EOF_ZENV'
export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.dotnet/tools:$PATH"

export ASPIRE_CONTAINER_RUNTIME=podman
unset SSL_CERT_DIR

EOF_ZENV

# ---------------------------------------------------------------------------
# Zsh configuration
# ---------------------------------------------------------------------------

cat > "$HOME/.zshrc" <<'EOF_ZRC'
export ZSH="$HOME/.oh-my-zsh"

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------

ZSH_THEME=""

# ---------------------------------------------------------------------------
# Oh My Zsh plugins
# ---------------------------------------------------------------------------

plugins=(
  gh
  git
  gitignore
  git-commit
  git-auto-fetch

  npm
  node
  ssh
  dnf
  sudo
  podman
  dotnet
  python

  encode64

  aliases
  colorize
  command-not-found
  colored-man-pages

  zsh-completions
  zsh-autocomplete
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# Prompt engine
# ---------------------------------------------------------------------------

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

[[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/starship-adaptive.zsh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/starship-adaptive.zsh"

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------

HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"

setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

zstyle ':autocomplete:history-search-backward:*' list-lines 10

zstyle ':autocomplete:history-incremental-search-backward:*' list-lines 2000

if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

# ---------------------------------------------------------------------------
# Autosuggestions
# ---------------------------------------------------------------------------

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

bindkey '^ ' autosuggest-accept

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
EOF_ZRC

# ---------------------------------------------------------------------------
# Default shell
# ---------------------------------------------------------------------------

zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"

if [ "$current_shell" != "$zsh_path" ]; then
  log "Setting Zsh as the default shell for $USER"

  sudo usermod \
    --shell "$zsh_path" \
    "$USER"

  ok "Default shell changed to $zsh_path"
else
  ok "Zsh is already the default shell for $USER"
fi

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
  err "Oh My Zsh validation failed."
  exit 1
fi

if [ ! -f "$HOME/.zshrc" ]; then
  err ".zshrc validation failed."
  exit 1
fi

if [ ! -f "$HOME/.zshenv" ]; then
  err ".zshenv validation failed."
  exit 1
fi

echo
echo "Zsh configuration"
echo "-----------------"
echo "User:        $USER"
echo "Zsh:         $zsh_path"
echo "Oh My Zsh:  $HOME/.oh-my-zsh"
echo "Prompt:      starship"
echo

ok "Zsh configured successfully."
echo "Starship is the default prompt engine and is installed by the next module."
