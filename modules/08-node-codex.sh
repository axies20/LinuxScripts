#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora; require_sudo

log "Installing Node.js and npm"
sudo dnf install -y nodejs npm

log "Using a user-owned npm global prefix"
NPM_PREFIX="$HOME/.local/npm"
mkdir -p "$NPM_PREFIX"
npm config set prefix "$NPM_PREFIX"
append_line_once 'export PATH="$HOME/.local/npm/bin:$PATH"' "$HOME/.bashrc"
export PATH="$NPM_PREFIX/bin:$PATH"

log "Checking OpenAI Codex CLI"
installed_codex_version="$(npm list -g --depth=0 @openai/codex 2>/dev/null | sed -n 's/.*@openai\/codex@\([^[:space:]]*\).*/\1/p' | head -1)"
latest_codex_version="$(npm view @openai/codex version 2>/dev/null || true)"

if [ -n "$installed_codex_version" ] && [ "$installed_codex_version" = "$latest_codex_version" ]; then
  ok "OpenAI Codex CLI $installed_codex_version is already the latest version; skipping download"
else
  [ -n "$latest_codex_version" ] || warn "Could not determine the latest Codex CLI version; asking npm to check."
  npm install -g @openai/codex
fi

node --version
npm --version
codex --version || true
