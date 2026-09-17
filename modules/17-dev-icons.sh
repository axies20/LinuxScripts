#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-3.5.0}"
MAPPING="$ROOT/config/dev-icons.tsv"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/fedora-setup/dev-icons"
ICON_ROOT="$DATA_HOME/icons/hicolor/scalable/mimetypes"
BASE_ROOT="$CACHE_HOME/base"
GLYPH_NAMES="$CACHE_HOME/glyphnames.json"
SYMBOLS_DIR="$CACHE_HOME/nerd-fonts-$NERD_FONTS_VERSION"
SYMBOLS_FONT="$SYMBOLS_DIR/SymbolsNerdFont-Regular.ttf"
DEFAULT_COLOR="#5E5E5E"

[ -f "$MAPPING" ] || { err "Missing developer icon mapping: $MAPPING"; exit 1; }

if ! command -v fontforge >/dev/null 2>&1; then
  require_sudo
  install_packages_if_missing fontforge
fi
if ! command -v update-mime-database >/dev/null 2>&1; then
  require_sudo
  install_packages_if_missing shared-mime-info
fi

mkdir -p "$CACHE_HOME" "$BASE_ROOT" "$ICON_ROOT" "$SYMBOLS_DIR"

if [ ! -f "$SYMBOLS_FONT" ]; then
  tmp="$(mktemp -d)"
  archive="$tmp/NerdFontsSymbolsOnly.zip"
  url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/NerdFontsSymbolsOnly.zip"
  log "Downloading Nerd Fonts Symbols Only v$NERD_FONTS_VERSION"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 -o "$archive" "$url"
  unzip -q -o "$archive" -d "$SYMBOLS_DIR"
  found="$(find "$SYMBOLS_DIR" -type f -name 'SymbolsNerdFont-Regular.ttf' -print -quit)"
  if [ -z "$found" ]; then
    rm -rf "$tmp"
    err "SymbolsNerdFont-Regular.ttf was not found in Nerd Fonts archive."
    exit 1
  fi
  if [ "$found" != "$SYMBOLS_FONT" ]; then
    cp "$found" "$SYMBOLS_FONT"
  fi
  rm -rf "$tmp"
fi

if [ ! -f "$GLYPH_NAMES" ]; then
  log "Downloading Nerd Fonts glyph catalogue v$NERD_FONTS_VERSION"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    -o "$GLYPH_NAMES" \
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v${NERD_FONTS_VERSION}/glyphnames.json"
fi

# Build an exact MIME -> glyph/color manifest from every MIME definition owned
# by this repository. Rules in config/dev-icons.tsv are intentionally glob-like
# so newly added related MIME types automatically inherit the right family icon.
RESOLVED="$CACHE_HOME/resolved.tsv"
python3 - "$ROOT/config/mime" "$MAPPING" "$GLYPH_NAMES" "$RESOLVED" <<'PY'
import fnmatch, json, pathlib, sys, xml.etree.ElementTree as ET
mime_dir, mapping_path, glyph_path, output_path = map(pathlib.Path, sys.argv[1:])

rules = []
for raw in mapping_path.read_text().splitlines():
    if not raw or raw.lstrip().startswith('#'):
        continue
    parts = raw.split('\t')
    if len(parts) < 2:
        continue
    rules.append((parts[0], parts[1], parts[2] if len(parts) > 2 else '#5E5E5E'))

glyphs = json.loads(glyph_path.read_text())
fallback = 'nf-md-file_code_outline'
if fallback not in glyphs:
    raise SystemExit(f'Missing Nerd Fonts fallback glyph: {fallback}')

mimes = set()
ns = {'m': 'http://www.freedesktop.org/standards/shared-mime-info'}
for path in sorted(mime_dir.glob('*.xml')):
    root = ET.parse(path).getroot()
    for node in root.findall('m:mime-type', ns):
        value = node.attrib.get('type')
        if value:
            mimes.add(value)

rows = []
for mime in sorted(mimes):
    glyph, color = fallback, '#5E5E5E'
    for pattern, candidate, candidate_color in rules:
        if fnmatch.fnmatchcase(mime.lower(), pattern.lower()):
            if candidate in glyphs:
                glyph = candidate
            color = candidate_color
            break
    code = glyphs[glyph]['code']
    rows.append((mime, glyph, code, color))

output_path.write_text(''.join('\t'.join(row) + '\n' for row in rows))
print(f'Resolved {len(rows)} MIME types')
PY

EXPORT_SCRIPT="$CACHE_HOME/export-glyph.py"
cat > "$EXPORT_SCRIPT" <<'PY'
import fontforge, os, sys
font_path, code_hex, output = sys.argv[1:]
font = fontforge.open(font_path)
codepoint = int(code_hex, 16)
if codepoint not in font:
    raise SystemExit(f'Glyph U+{code_hex} is absent from {font_path}')
glyph = font[codepoint]
glyph.export(output)
font.close()
PY

log "Generating monochrome GNOME-style developer MIME icons"
count=0
while IFS=$'\t' read -r mime glyph code accent; do
  [ -n "$mime" ] || continue
  icon_name="${mime//\//-}"
  base="$BASE_ROOT/$icon_name.svg"
  target="$ICON_ROOT/$icon_name.svg"
  symbolic="$ICON_ROOT/$icon_name-symbolic.svg"

  if [ ! -f "$base" ]; then
    fontforge -quiet -script "$EXPORT_SCRIPT" "$SYMBOLS_FONT" "$code" "$base" >/dev/null 2>&1
  fi

  # FontForge exports vector paths. A color on the root SVG is inherited by
  # those paths, giving us one immutable geometry and switchable presentation.
  sed -E "0,/<svg /s//<svg style=\"fill:${DEFAULT_COLOR}\" /" "$base" > "$target"
  cp "$target" "$symbolic"
  count=$((count + 1))
done < "$RESOLVED"

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
fi

STYLE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fedora-setup"
mkdir -p "$STYLE_DIR"
printf '%s\n' 'monochrome' > "$STYLE_DIR/dev-icons-style"

ok "Installed $count monochrome developer MIME icons"
echo "Re-run './install.sh dev-icons' at any time to restore the monochrome GNOME style."
echo "Run './install.sh dev-icons-color' to choose a color style."
