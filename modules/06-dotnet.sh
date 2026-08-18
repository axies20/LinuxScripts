#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing the system-wide .NET 10 SDK updater"
sudo install -Dm755 \
  "$ROOT/system/update-dotnet-sdk.sh" \
  /usr/local/sbin/update-dotnet-sdk
sudo install -Dm644 \
  "$ROOT/config/systemd/dotnet-sdk-update.service" \
  /etc/systemd/system/dotnet-sdk-update.service
sudo install -Dm644 \
  "$ROOT/config/systemd/dotnet-sdk-update.timer" \
  /etc/systemd/system/dotnet-sdk-update.timer

log "Installing the latest stable .NET 10 SDK from Microsoft"
sudo /usr/local/sbin/update-dotnet-sdk

mapfile -t packaged_dotnet < <(
  rpm -qa --qf '%{NAME}\n' |
    awk '/^(dotnet|aspnetcore|netstandard)(-|$)/' |
    sort -u
)
if [ "${#packaged_dotnet[@]}" -gt 0 ]; then
  log "Removing superseded Fedora .NET packages"
  sudo dnf remove -y "${packaged_dotnet[@]}"
fi

sudo systemctl daemon-reload
sudo systemctl enable --now dotnet-sdk-update.timer

export PATH="/usr/local/bin:$PATH"
if [ "$(readlink -f "$(command -v dotnet)")" != "/usr/local/share/dotnet/dotnet" ]; then
  err "The Microsoft .NET installation is not first on PATH."
  exit 1
fi

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
