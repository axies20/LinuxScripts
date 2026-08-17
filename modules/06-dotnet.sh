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
  installed_version="$(dotnet_global_tool_version "$tool")"
  latest_version="$(nuget_latest_stable_version "$tool" || true)"

  if [ -n "$installed_version" ] && [ "$installed_version" = "$latest_version" ]; then
    ok "$tool $installed_version is already the latest version; skipping"
  elif [ -n "$installed_version" ]; then
    [ -n "$latest_version" ] || warn "Could not determine the latest $tool version; asking dotnet to check."
    dotnet tool update -g "$tool" || warn "Could not update $tool"
  else
    dotnet tool install -g "$tool"
  fi
done
