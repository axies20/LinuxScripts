#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"

require_fedora
require_sudo

log "Installing Node.js and npm"
sudo dnf install -y nodejs npm

log "Using a user-owned npm global prefix"

NPM_PREFIX="$HOME/.local/npm"

mkdir -p "$NPM_PREFIX"

npm config set prefix "$NPM_PREFIX"

append_line_once \
  'export PATH="$HOME/.local/npm/bin:$PATH"' \
  "$HOME/.bashrc"

export PATH="$NPM_PREFIX/bin:$PATH"

log "Checking OpenAI Codex CLI"

installed_codex_version="$(
  {
    npm list -g --depth=0 @openai/codex 2>/dev/null || true
  } |
  sed -n 's/.*@openai\/codex@\([^[:space:]]*\).*/\1/p' |
  head -1
)"

latest_codex_version="$(
  npm view @openai/codex version 2>/dev/null || true
)"

if [ -z "$installed_codex_version" ]; then

  log "Installing OpenAI Codex CLI"

  if [ -n "$latest_codex_version" ]; then
    npm install -g "@openai/codex@$latest_codex_version"
  else
    warn "Could not determine the latest Codex CLI version. Installing npm latest."
    npm install -g @openai/codex
  fi

elif [ -n "$latest_codex_version" ] &&
     [ "$installed_codex_version" = "$latest_codex_version" ]; then

  ok "OpenAI Codex CLI $installed_codex_version is already the latest version"

else

  log "Updating OpenAI Codex CLI"

  if [ -n "$latest_codex_version" ]; then
    echo "Installed: $installed_codex_version"
    echo "Latest:    $latest_codex_version"

    npm install -g "@openai/codex@$latest_codex_version"
  else
    warn "Could not determine the latest Codex CLI version. Asking npm to update."
    npm install -g @openai/codex@latest
  fi

fi

log "Installed versions"

node --version
npm --version

if command -v codex >/dev/null 2>&1; then
  codex --version
else
  err "Codex CLI installation completed, but 'codex' is not available on PATH."
  echo "Expected binary directory: $NPM_PREFIX/bin"
  exit 1
fi

ok "Node.js, npm and OpenAI Codex CLI are ready."
