#!/usr/bin/env bash
set -u
commands=(git podman buildah skopeo dotnet node npm codex zsh starship flatpak gnome-extensions xdg-mime)
for cmd in "${commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then printf 'OK      %-20s %s\n' "$cmd" "$(command -v "$cmd")"; else printf 'MISSING %s\n' "$cmd"; fi
done
if [ -x "$HOME/.aspire/bin/aspire" ]; then
  printf 'OK      %-20s %s\n' aspire "$HOME/.aspire/bin/aspire"
else
  printf 'MISSING aspire\n'
fi
