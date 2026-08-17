#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing multimedia codecs"
sudo dnf group install -y multimedia || warn "The multimedia group could not be installed."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || warn "ffmpeg-free swap was not required or unavailable."
sudo dnf upgrade -y @multimedia --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin || true
sudo dnf group install -y sound-and-video || warn "The sound-and-video group is unavailable."

sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1 || true
install_if_available openh264 gstreamer1-plugin-openh264 mozilla-openh264
