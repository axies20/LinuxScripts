#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

if ! lspci | grep -Eiq 'nvidia.*(vga|3d|display)|(vga|3d|display).*nvidia'; then
  echo "No NVIDIA GPU detected; skipping NVIDIA driver module."
  exit 0
fi

log "NVIDIA GPU detected; installing RPM Fusion driver packages"
install_packages_if_missing kernel-devel kernel-headers gcc make akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda
install_if_available nvidia-settings nvidia-modprobe nvidia-persistenced xorg-x11-drv-nvidia-power

echo "NVIDIA packages installed. Reboot only after akmods has completed building the kernel module."
