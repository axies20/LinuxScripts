#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing rootless Podman toolchain"
install_packages_if_missing podman podman-compose buildah skopeo
install_if_available podman-tui

podman --version
podman info >/dev/null

echo "Podman socket is intentionally NOT enabled; Aspire can use Podman directly."
