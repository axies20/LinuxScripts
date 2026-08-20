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

# Starship calculates these values in its own precmd hook. This file is sourced
# after `starship init zsh`, so exporting them here makes them available to the
# custom success/error duration modules.
_starship_export_duration_state() {
  export STARSHIP_TAIL_DURATION="${STARSHIP_DURATION:-0}"
  export STARSHIP_TAIL_STATUS="${STARSHIP_CMD_STATUS:-0}"
}

add-zsh-hook precmd _starship_export_duration_state

TRAPWINCH() {
  _starship_select_config
  if [[ -n ${ZLE_STATE-} ]]; then
    zle reset-prompt
  fi
}
