#!/usr/bin/env bash
set -u
commands=(git podman buildah skopeo dotnet node npm codex zsh starship flatpak gnome-extensions xdg-mime fc-cache fc-match)
for cmd in "${commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then printf 'OK      %-20s %s\n' "$cmd" "$(command -v "$cmd")"; else printf 'MISSING %s\n' "$cmd"; fi
done
if [ -x "$HOME/.aspire/bin/aspire" ]; then
  printf 'OK      %-20s %s\n' aspire "$HOME/.aspire/bin/aspire"
else
  printf 'MISSING aspire\n'
fi

echo
printf '%s\n' 'Nerd Font checks:'
for family in 'JetBrainsMono Nerd Font' 'FiraCode Nerd Font' 'MesloLGS Nerd Font'; do
  match="$(fc-match -f '%{family}\n' "$family" 2>/dev/null | head -n1 || true)"
  if printf '%s' "$match" | grep -qi 'Nerd Font'; then
    printf 'OK      %-24s %s\n' "$family" "$match"
  else
    printf 'MISSING %-24s\n' "$family"
  fi
done
