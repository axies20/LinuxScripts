#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run LinuxScripts as root or with sudo."
    echo
    echo "Run it as your normal user:"
    echo "  ./install.sh"
    echo
    echo "The installer will request sudo automatically when required."
    exit 1
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/common.sh"

modules=(
  01-system
  02-repositories
  03-packages
  04-codecs
  05-podman
  06-dotnet
  07-aspire
  08-node-codex
  09-zsh
  10-nerd-fonts
  11-starship
  12-gnome
  13-nautilus
  14-flatpak
  15-nvidia
  16-mime
  17-finalize
)

list_modules() {
  echo "Available modules:"
  local module
  for module in "${modules[@]}"; do
    printf '  %-18s  alias: %s\n' "$module" "${module#*-}"
  done
}

resolve_module() {
  local requested="${1%.sh}"
  local exact="$ROOT/modules/$requested.sh"

  if [ -f "$exact" ]; then
    printf '%s\n' "$requested"
    return 0
  fi

  # Numeric prefixes are installation order, not stable identifiers.
  # 10-starship and starship both resolve to the current *-starship.sh.
  local semantic="$requested"
  if [[ "$semantic" =~ ^[0-9]+-(.+)$ ]]; then
    semantic="${BASH_REMATCH[1]}"
  fi

  local matches=()
  local candidate
  shopt -s nullglob
  for candidate in "$ROOT"/modules/[0-9][0-9]-"$semantic".sh; do
    matches+=("$(basename "$candidate" .sh)")
  done
  shopt -u nullglob

  if [ "${#matches[@]}" -eq 1 ]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  if [ "${#matches[@]}" -gt 1 ]; then
    err "Ambiguous module name: $1"
    printf 'Matches: %s\n' "${matches[*]}" >&2
  else
    err "Module not found: $1"
  fi
  return 1
}

if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
  list_modules
  exit 0
fi

require_fedora

if [ "$#" -gt 0 ]; then
  requested_modules=()
  for requested in "$@"; do
    if ! resolved="$(resolve_module "$requested")"; then
      echo >&2
      list_modules >&2
      exit 1
    fi
    requested_modules+=("$resolved")
  done
  modules=("${requested_modules[@]}")
fi

if ! command -v sudo >/dev/null 2>&1; then
  err "sudo is not installed."
  exit 1
fi

echo "Fedora Setup will run ${#modules[@]} module(s) automatically."
echo "No Enter key is required between modules."
echo "Only sudo authentication can request input, once at the beginning."
echo

if ! sudo -n true >/dev/null 2>&1; then
  echo "Administrator access is required for system changes."
  echo "sudo may ask for your password once now:"
  sudo -v
fi

export FEDORA_SETUP_SUDO_READY=1
export FEDORA_SETUP_NONINTERACTIVE=1
export GIT_TERMINAL_PROMPT=0
export NPM_CONFIG_YES=true
export PATH="$HOME/.local/bin:$HOME/.local/npm/bin:$HOME/.dotnet/tools:$PATH"

(
  while true; do
    sudo -n true >/dev/null 2>&1 || exit 0
    sleep 50
  done
) </dev/null &
SUDO_KEEPALIVE_PID=$!

cleanup() {
  kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

for module in "${modules[@]}"; do
  script="$ROOT/modules/$module.sh"
  log "Running $module"
  if ! bash "$script" </dev/null; then
    err "$module failed. The installer stopped instead of waiting for hidden input."
    exit 1
  fi
  ok "$module completed — continuing automatically"
done

log "Fedora setup finished"
echo "No automatic reboot is performed."
echo "Log out/in (or reboot) to apply shell, GNOME, NVIDIA/kernel and session changes."
