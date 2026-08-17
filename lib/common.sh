#!/usr/bin/env bash

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
err()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; }

require_fedora() {
    if [ ! -f /etc/fedora-release ]; then
        err "This setup is intended for Fedora Workstation."
        exit 1
    fi
}

require_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
        err "sudo is not installed."
        exit 1
    fi

    # The top-level installer authenticates once and keeps sudo alive.
    # Individual modules can still be executed directly; in that case they
    # authenticate once here with an explicit explanation.
    if [ "${FEDORA_SETUP_SUDO_READY:-0}" = "1" ]; then
        return 0
    fi

    if ! sudo -n true >/dev/null 2>&1; then
        echo "Administrator access is required for this module."
        echo "sudo may ask for your password once now."
        sudo -v
    fi
}

append_line_once() {
    local line="$1" file="$2"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    grep -qxF "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

install_if_available() {
    local package
    for package in "$@"; do
        if dnf -q info "$package" >/dev/null 2>&1; then
            sudo dnf install -y "$package"
        else
            warn "Package '$package' is unavailable; skipping."
        fi
    done
}
