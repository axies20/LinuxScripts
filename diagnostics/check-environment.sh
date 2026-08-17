#!/usr/bin/env bash
set -u

commands=(git podman buildah skopeo dotnet aspire node npm codex zsh starship flatpak gnome-extensions xdg-mime)
for cmd in "${commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'OK      %-20s %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf 'MISSING %s\n' "$cmd"
  fi
done

for family in "JetBrainsMono Nerd Font" "FiraCode Nerd Font" "MesloLGS NF"; do
  if fc-list : family 2>/dev/null | grep -Fqi "$family"; then
    printf 'OK      %-20s %s\n' "font" "$family"
  else
    printf 'MISSING font: %s\n' "$family"
  fi
done
