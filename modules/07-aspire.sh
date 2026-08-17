#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

log "Installing/updating Aspire CLI"
curl -fsSL https://aspire.dev/install.sh | bash
export PATH="$HOME/.aspire/bin:$PATH"

append_line_once 'export PATH="$HOME/.aspire/bin:$PATH"' "$HOME/.bashrc"
append_line_once 'export ASPIRE_CONTAINER_RUNTIME=podman' "$HOME/.bashrc"
append_line_once 'export SSL_CERT_DIR="${SSL_CERT_DIR:+$SSL_CERT_DIR:}/etc/pki/tls/certs:$HOME/.aspnet/dev-certs/trust"' "$HOME/.bashrc"

export ASPIRE_CONTAINER_RUNTIME=podman
export SSL_CERT_DIR="${SSL_CERT_DIR:+$SSL_CERT_DIR:}/etc/pki/tls/certs:$HOME/.aspnet/dev-certs/trust"

aspire --version
log "Refreshing Aspire development certificate"
aspire certs clean || true
aspire certs trust

log "Aspire diagnostics"
aspire doctor || warn "aspire doctor reported warnings; review them after login/reboot."
