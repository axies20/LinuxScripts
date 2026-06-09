# ---------- Zsh + Oh-My-Zsh + Powerlevel10k ----------
set -e

# 0) Пакеты
sudo dnf install -y zsh git curl util-linux-user

# 1) Установка Oh My Zsh без автозапуска и без смены shell
export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 2) Плагины и тема
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[ -d "$ZSH_CUSTOM/plugins/zsh-completions" ] || \
  git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"

[ -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ] || \
  git clone --depth=1 https://github.com/marlonrichert/zsh-autocomplete "$ZSH_CUSTOM/plugins/zsh-autocomplete"

[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] || \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# 3) Общие env для zsh
cat > "$HOME/.zshenv" <<'ZENV'
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
ZENV

# 4) Бэкап старого .zshrc
if [ -f "$HOME/.zshrc" ]; then
  cp -f "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
fi

# 5) Новый .zshrc
cat > "$HOME/.zshrc" <<'ZRC'
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
# syntax-highlighting лучше оставлять последним
plugins=(
  git
  git-auto-fetch
  npm
  nvm
  sudo
  docker
  docker-compose
  dotnet
  pip
  kubectl
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

# Powerlevel10k config
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# История
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=$HOME/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# Удобства completion
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Настройки autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
bindkey '^ ' autosuggest-accept   # Ctrl+Space принять подсказку

# Полезные алиасы
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
ZRC

# 6) Сделать zsh shell по умолчанию
if [ "$(basename "$SHELL")" != "zsh" ]; then
  chsh -s "$(command -v zsh)"
fi

echo
echo "Готово."
echo "Перезапусти терминал или выполни: exec zsh"
echo "Потом запусти: p10k configure"
# ---------------------------------------------------
