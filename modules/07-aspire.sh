#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

export PATH="$HOME/.dotnet/tools:$PATH"

if ! command -v dotnet >/dev/null 2>&1; then
  err ".NET SDK is required before Aspire. Run: ./install.sh dotnet"
  exit 1
fi

log "Installing/updating Aspire CLI as a .NET global tool"
if dotnet tool list -g | awk 'NR>2 {print tolower($1)}' | grep -qx 'aspire.cli'; then
  dotnet tool update -g Aspire.Cli
else
  dotnet tool install -g Aspire.Cli
fi

append_line_once 'export PATH="$HOME/.dotnet/tools:$PATH"' "$HOME/.bashrc"
append_line_once 'export ASPIRE_CONTAINER_RUNTIME=podman' "$HOME/.bashrc"
append_line_once 'export SSL_CERT_DIR="${SSL_CERT_DIR:+$SSL_CERT_DIR:}/etc/pki/tls/certs:$HOME/.aspnet/dev-certs/trust"' "$HOME/.bashrc"

export ASPIRE_CONTAINER_RUNTIME=podman
export SSL_CERT_DIR="${SSL_CERT_DIR:+$SSL_CERT_DIR:}/etc/pki/tls/certs:$HOME/.aspnet/dev-certs/trust"

if ! command -v aspire >/dev/null 2>&1; then
  err "Aspire CLI was installed but is not available on PATH. Expected: $HOME/.dotnet/tools/aspire"
  exit 1
fi

aspire --version

log "Refreshing Aspire development certificate"
aspire certs clean --non-interactive --nologo || true
aspire certs trust --non-interactive --nologo

log "Aspire diagnostics"
aspire doctor --non-interactive --nologo || warn "aspire doctor reported warnings; review them after login/reboot."
