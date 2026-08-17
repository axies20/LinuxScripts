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

log "Installing/updating OpenAI Codex CLI"
npm install -g @openai/codex

node --version
npm --version
codex --version || true
