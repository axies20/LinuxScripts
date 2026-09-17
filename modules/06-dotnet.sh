#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

dotnet_manager_repo="https://github.com/axies20/DotnetManager.git"
dotnet_manager_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$dotnet_manager_dir"
}
trap cleanup EXIT INT TERM

log "Installing DotnetManager and the configured system-wide .NET SDKs"
git clone --depth 1 "$dotnet_manager_repo" "$dotnet_manager_dir/DotnetManager"
bash "$dotnet_manager_dir/DotnetManager/install.sh"

mapfile -t packaged_dotnet < <(
  rpm -qa --qf '%{NAME}\n' |
    awk '/^(dotnet|aspnetcore|netstandard)(-|$)/' |
    sort -u
)
if [ "${#packaged_dotnet[@]}" -gt 0 ]; then
  log "Removing superseded Fedora .NET packages"
  sudo dnf remove -y "${packaged_dotnet[@]}"
fi

export PATH="/usr/local/bin:$PATH"
if [ "$(readlink -f "$(command -v dotnet)")" != "/usr/local/share/dotnet/dotnet" ]; then
  err "The Microsoft .NET installation is not first on PATH."
  exit 1
fi

if [ "$(command -v dotnet-manager)" != "/usr/local/bin/dotnet-manager" ]; then
  err "DotnetManager is not available from /usr/local/bin."
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
