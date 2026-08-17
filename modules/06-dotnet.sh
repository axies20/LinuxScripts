#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing .NET 10 SDK from Fedora repositories"
sudo dnf install -y dotnet-sdk-10.0

mkdir -p "$HOME/.dotnet/tools"
append_line_once 'export PATH="$HOME/.dotnet/tools:$PATH"' "$HOME/.bashrc"

dotnet --info

log "Installing/updating .NET global tools"
tools=(dotnet-ef dotnet-format coverlet.console dotnet-reportgenerator-globaltool)
for tool in "${tools[@]}"; do
  if dotnet tool list -g | awk 'NR>2 {print $1}' | grep -qx "$tool"; then
    dotnet tool update -g "$tool" || warn "Could not update $tool"
  else
    dotnet tool install -g "$tool"
  fi
done
