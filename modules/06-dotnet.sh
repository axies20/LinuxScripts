#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

dotnet_manager_repo="https://github.com/dnm-project/DotnetManager.git"
dotnet_manager_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$dotnet_manager_dir"
}
trap cleanup EXIT INT TERM

log "Installing dnm and the latest LTS and STS .NET SDKs"
git clone --depth 1 "$dotnet_manager_repo" "$dotnet_manager_dir/DotnetManager"
DOTNET_MANAGER_REPOSITORY="dnm-project/DotnetManager" \
  sh "$dotnet_manager_dir/DotnetManager/install.sh"

mapfile -t packaged_dotnet < <(
  rpm -qa --qf '%{NAME}\n' |
    awk '/^(dotnet|aspnetcore|netstandard)(-|$)/' |
    sort -u
)
if [ "${#packaged_dotnet[@]}" -gt 0 ]; then
  log "Removing superseded Fedora .NET packages"
  sudo dnf remove -y "${packaged_dotnet[@]}"
fi

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.local/bin:$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"

if [ "$(command -v dnm || true)" != "$HOME/.local/bin/dnm" ]; then
  err "dnm is not available from $HOME/.local/bin."
  exit 1
fi

dnm install latest --release-type Lts
dnm install latest --release-type Sts

if [ ! -x "$DOTNET_ROOT/dotnet" ]; then
  err ".NET was not installed in $DOTNET_ROOT."
  exit 1
fi

legacy_dotnet_manager="/usr/local/bin/dotnet-manager"
if [ -f "$legacy_dotnet_manager" ] && \
    grep -qF 'readonly PROGRAM_NAME="dotnet-manager"' "$legacy_dotnet_manager"
then
  log "Removing the superseded system-wide dotnet-manager installation"

  if systemctl list-unit-files dotnet-manager-update.timer --no-legend \
      2>/dev/null | grep -q '^dotnet-manager-update.timer'
  then
    sudo systemctl disable --now dotnet-manager-update.timer
  fi

  if [ "$(readlink -f /usr/local/bin/dotnet 2>/dev/null || true)" = \
      "/usr/local/share/dotnet/dotnet" ]
  then
    sudo rm -f /usr/local/bin/dotnet
  fi

  sudo rm -f \
    "$legacy_dotnet_manager" \
    /usr/local/share/zsh/site-functions/_dotnet-manager \
    /etc/systemd/system/dotnet-manager-update.service \
    /etc/systemd/system/dotnet-manager-update.timer
  sudo rm -rf /usr/local/share/dotnet /etc/dotnet-manager
  sudo systemctl daemon-reload
fi

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
