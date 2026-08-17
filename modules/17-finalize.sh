#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

log "Final checks"
printf '%-16s %s\n' Fedora "$(rpm -E %fedora 2>/dev/null || echo unknown)"
printf '%-16s %s\n' Podman "$(podman --version 2>/dev/null || echo missing)"
printf '%-16s %s\n' .NET "$(dotnet --version 2>/dev/null || echo missing)"
printf '%-16s %s\n' Aspire "$($HOME/.aspire/bin/aspire --version 2>/dev/null || echo missing)"
printf '%-16s %s\n' Node "$(node --version 2>/dev/null || echo missing)"
printf '%-16s %s\n' Zsh "$(zsh --version 2>/dev/null || echo missing)"
printf '%-16s %s\n' Starship "$(starship --version 2>/dev/null | head -n1 || echo missing)"

echo
echo "No automatic reboot is performed."
echo "Log out/in or reboot when convenient."
