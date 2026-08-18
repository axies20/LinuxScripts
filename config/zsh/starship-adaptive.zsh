# Select a compact Starship profile when the terminal is narrow.

_starship_select_config() {
  local config_root="${XDG_CONFIG_HOME:-$HOME/.config}"

  if (( ${COLUMNS:-120} < 90 )); then
    export STARSHIP_CONFIG="$config_root/starship-compact.toml"
  else
    export STARSHIP_CONFIG="$config_root/starship.toml"
  fi
}

_starship_select_config

autoload -Uz add-zsh-hook
add-zsh-hook precmd _starship_select_config

TRAPWINCH() {
  _starship_select_config
  if [[ -o zle ]]; then
    zle reset-prompt
  fi
}
