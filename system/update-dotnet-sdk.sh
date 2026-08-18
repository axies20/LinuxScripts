#!/usr/bin/env bash
set -Eeuo pipefail

channel="10.0"
install_root="/usr/local/share/dotnet"
metadata_url="https://builds.dotnet.microsoft.com/dotnet/release-metadata/${channel}/releases.json"
installer_url="https://dot.net/v1/dotnet-install.sh"

for command_name in curl jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: Required command is missing: $command_name" >&2
    exit 1
  fi
done

work_dir="$(mktemp -d)"
stage_dir=""
cleanup() {
  rm -rf -- "$work_dir"
  if [ -n "$stage_dir" ] && [ -d "$stage_dir" ]; then
    rm -rf -- "$stage_dir"
  fi
}
trap cleanup EXIT INT TERM

curl -fsSL --connect-timeout 15 --retry 3 \
  "$metadata_url" -o "$work_dir/releases.json"
latest_version="$(jq -er '."latest-sdk"' "$work_dir/releases.json")"

installed_version=""
if [ -x "$install_root/dotnet" ]; then
  # mktemp creates staging directories as 0700. Ensure the activated SDK is
  # traversable by normal users, and repair installations made by older runs.
  chmod 0755 "$install_root"
  ln -sfn "$install_root/dotnet" /usr/local/bin/dotnet
  installed_version="$($install_root/dotnet --list-sdks 2>/dev/null |
    awk '{print $1}' | sort -V | tail -1)"
fi

if [ "$installed_version" = "$latest_version" ]; then
  echo ".NET SDK $latest_version is already current."
  exit 0
fi

echo "Updating system .NET SDK: ${installed_version:-not installed} -> $latest_version"
curl -fsSL --connect-timeout 15 --retry 3 \
  "$installer_url" -o "$work_dir/dotnet-install.sh"

stage_dir="$(mktemp -d /usr/local/share/.dotnet-stage.XXXXXX)"
chmod 0755 "$stage_dir"
bash "$work_dir/dotnet-install.sh" \
  --version "$latest_version" \
  --install-dir "$stage_dir" \
  --no-path

staged_version="$($stage_dir/dotnet --version)"
if [ "$staged_version" != "$latest_version" ]; then
  echo "ERROR: Expected SDK $latest_version, staged SDK is $staged_version." >&2
  exit 1
fi

previous_root="/usr/local/share/.dotnet-previous"
rm -rf -- "$previous_root"
if [ -d "$install_root" ]; then
  mv -- "$install_root" "$previous_root"
fi

if ! mv -- "$stage_dir" "$install_root"; then
  if [ -d "$previous_root" ]; then
    mv -- "$previous_root" "$install_root"
  fi
  echo "ERROR: Could not activate the staged .NET SDK." >&2
  exit 1
fi
stage_dir=""

ln -sfn "$install_root/dotnet" /usr/local/bin/dotnet
rm -rf -- "$previous_root"
echo ".NET SDK $latest_version installed in $install_root."
