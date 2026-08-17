#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

sudo dnf install -y gnome-tweaks jq curl wget

if ! command -v gnome-extensions >/dev/null 2>&1 || ! command -v gnome-shell >/dev/null 2>&1; then
  warn "GNOME Shell extension tools are unavailable; skipping extensions."
  exit 0
fi

shell_major="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
extensions=(
  blur-my-shell@aunetx
  dash-to-dock@micxgx.gmail.com
  gtk4-ding@smedius.gitlab.com
  clipboard-indicator@tudmotu.com
  osd-volume-number@deminder
  search-light@icedman.github.com
  fullscreen-avoider@noobsai.github.com
  gnome-fuzzy-app-search@gnome-shell-extensions.Czarlie.gitlab.com
  gamebar-overlay@dekotale.github.io
)

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for extension in "${extensions[@]}"; do
  log "GNOME extension: $extension"
  json="$(curl -LfsG --data-urlencode "search=$extension" https://extensions.gnome.org/extension-query/ || true)"
  tag="$(jq -r --arg uuid "$extension" --arg shell "$shell_major" '.extensions[]? | select(.uuid == $uuid) | .shell_version_map[$shell].pk // empty' <<<"$json" | head -1)"
  if [ -z "$tag" ]; then
    warn "No GNOME $shell_major compatible build for $extension; skipping."
    continue
  fi
  zip="$tmp/$extension.zip"
  if wget -qO "$zip" "https://extensions.gnome.org/download-extension/${extension}.shell-extension.zip?version_tag=${tag}"; then
    gnome-extensions install --force "$zip" || true
    gnome-extensions enable "$extension" || warn "Installed $extension but could not enable it in this session."
  else
    warn "Could not download $extension"
  fi
done
