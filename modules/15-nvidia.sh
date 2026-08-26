#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

nvidia_devices="$(
  lspci -nn |
    grep -Ei 'nvidia.*(vga|3d|display)|(vga|3d|display).*nvidia' || true
)"

if [ -z "$nvidia_devices" ]; then
  echo "No NVIDIA GPU detected; skipping NVIDIA driver module."
  exit 0
fi

echo "Detected NVIDIA GPU(s):"
echo "$nvidia_devices"

driver_branch=""
branch_count=0

select_branch() {
  local branch="$1"

  if [ "$driver_branch" != "$branch" ]; then
    driver_branch="$branch"
    branch_count=$((branch_count + 1))
  fi
}

# NVIDIA architecture codes reported by lspci:
#   GB/GH/AD/GA/TU: current driver
#   GV/GP/GM:       580xx legacy driver
#   GK:             470xx legacy driver
#   GF:             390xx legacy driver
grep -Eq '\b(GB|GH|AD|GA|TU)[0-9A-Z]*\b' <<<"$nvidia_devices" && select_branch current
grep -Eq '\b(GV|GP|GM)[0-9A-Z]*\b' <<<"$nvidia_devices" && select_branch 580xx
grep -Eq '\bGK[0-9A-Z]*\b' <<<"$nvidia_devices" && select_branch 470xx
grep -Eq '\bGF[0-9A-Z]*\b' <<<"$nvidia_devices" && select_branch 390xx

if [ "$branch_count" -gt 1 ]; then
  err "Detected NVIDIA GPUs that require different driver branches."
  err "A single proprietary NVIDIA kernel module cannot safely serve this combination."
  exit 1
fi

if [ -z "$driver_branch" ]; then
  for installed_branch in 580xx 470xx 390xx; do
    if rpm -q "akmod-nvidia-$installed_branch" >/dev/null 2>&1; then
      driver_branch="$installed_branch"
      warn "GPU architecture was not recognized; preserving installed $installed_branch branch."
      break
    fi
  done
fi

if [ -z "$driver_branch" ] && rpm -q akmod-nvidia >/dev/null 2>&1; then
  driver_branch="current"
  warn "GPU architecture was not recognized; preserving the installed current branch."
fi

if [ -z "$driver_branch" ]; then
  err "Unable to determine the compatible NVIDIA driver branch from lspci output."
  err "Refusing to install a potentially incompatible driver."
  exit 1
fi

suffix=""
if [ "$driver_branch" != "current" ]; then
  suffix="-$driver_branch"
fi

for other_branch in current 580xx 470xx 390xx; do
  [ "$other_branch" = "$driver_branch" ] && continue

  other_suffix=""
  if [ "$other_branch" != "current" ]; then
    other_suffix="-$other_branch"
  fi

  if rpm -q "akmod-nvidia$other_suffix" >/dev/null 2>&1; then
    err "Installed NVIDIA branch '$other_branch' conflicts with detected branch '$driver_branch'."
    err "Refusing to remove or replace an installed driver automatically."
    exit 1
  fi
done

log "Installing RPM Fusion NVIDIA driver branch: $driver_branch"

install_packages_if_missing \
  kernel-devel \
  kernel-headers \
  gcc \
  make \
  "akmod-nvidia$suffix" \
  "xorg-x11-drv-nvidia$suffix" \
  "xorg-x11-drv-nvidia$suffix-cuda"

install_if_available \
  "nvidia-settings$suffix" \
  nvidia-modprobe \
  nvidia-persistenced \
  "xorg-x11-drv-nvidia$suffix-power"

echo "NVIDIA packages installed. Reboot only after akmods has completed building the kernel module."
