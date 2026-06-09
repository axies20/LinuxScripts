#!/usr/bin/env bash

set -euo pipefail

MIME_PACKAGES_DIR="$HOME/.local/share/mime/packages"
MIME_DIR="$HOME/.local/share/mime"
APPLICATIONS_DIR="$HOME/.local/share/applications"

mkdir -p "$MIME_PACKAGES_DIR"
mkdir -p "$APPLICATIONS_DIR"

read -rp "Enter file extension (e.g. slnx, xyz): " EXTENSION
read -rp "Enter MIME type (e.g. text/slnx or application/x-newtype): " MIME_TYPE
read -rp "Enter description (e.g. JetBrains Solution File): " DESCRIPTION

if [[ -z "$EXTENSION" || -z "$MIME_TYPE" || -z "$DESCRIPTION" ]]; then
    echo "Error: All fields must be filled in."
    exit 1
fi

# Remove leading dot if provided (e.g. .xyz → xyz)
EXTENSION="${EXTENSION#.}"

SAFE_FILE_NAME="$(echo "$MIME_TYPE" | tr '/.' '-' )"
XML_FILE="$MIME_PACKAGES_DIR/user-extension-${EXTENSION}.xml"

cat > "$XML_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="$MIME_TYPE">
    <comment>$DESCRIPTION</comment>
    <glob pattern="*.$EXTENSION"/>
  </mime-type>
</mime-info>
EOF

echo
echo "MIME type file created:"
echo "  $XML_FILE"
echo

echo "Updating MIME database..."
update-mime-database "$MIME_DIR"

echo "Updating desktop applications database..."
update-desktop-database "$APPLICATIONS_DIR"

echo
echo "Done."
echo "You can verify with:"
echo "  xdg-mime query filetype example.$EXTENSION"
