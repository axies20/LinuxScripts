#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
require_fedora

NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-3.5.0}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/fedora-setup/dev-icons"
APP_HOME="$DATA_HOME/fedora-setup/dev-icons"
BIN_HOME="$HOME/.local/bin"
SYSTEMD_HOME="$CONFIG_HOME/systemd/user"
MIME_HOME="$DATA_HOME/mime"
ICON_ROOT="$DATA_HOME/icons/hicolor/scalable/mimetypes"
SYMBOLS_DIR="$CACHE_HOME/nerd-fonts-$NERD_FONTS_VERSION"
SYMBOLS_FONT="$SYMBOLS_DIR/SymbolsNerdFont-Regular.ttf"
GLYPH_NAMES="$CACHE_HOME/glyphnames.json"
MIME_CATALOG="$APP_HOME/mimes.json"
WORKER="$BIN_HOME/dev-mime-icons"

if ! command -v fontforge >/dev/null 2>&1; then
  require_sudo
  install_packages_if_missing fontforge
fi
if ! command -v update-mime-database >/dev/null 2>&1; then
  require_sudo
  install_packages_if_missing shared-mime-info
fi

mkdir -p "$CACHE_HOME" "$APP_HOME" "$BIN_HOME" "$SYSTEMD_HOME" "$ICON_ROOT" "$SYMBOLS_DIR"

if [ ! -f "$SYMBOLS_FONT" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  archive="$tmp/NerdFontsSymbolsOnly.zip"
  url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/NerdFontsSymbolsOnly.zip"
  log "Downloading Nerd Fonts Symbols Only v$NERD_FONTS_VERSION"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 -o "$archive" "$url"
  unzip -q -o "$archive" -d "$SYMBOLS_DIR"
  found="$(find "$SYMBOLS_DIR" -type f -name 'SymbolsNerdFont-Regular.ttf' -print -quit)"
  [ -n "$found" ] || { err "SymbolsNerdFont-Regular.ttf was not found in Nerd Fonts archive."; exit 1; }
  [ "$found" = "$SYMBOLS_FONT" ] || cp "$found" "$SYMBOLS_FONT"
  rm -rf "$tmp"
  trap - RETURN
fi

if [ ! -f "$GLYPH_NAMES" ]; then
  log "Downloading Nerd Fonts glyph catalogue v$NERD_FONTS_VERSION"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    -o "$GLYPH_NAMES" \
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v${NERD_FONTS_VERSION}/glyphnames.json"
fi

# Snapshot only MIME metadata, never user files. The runtime resolver therefore
# does O(number of MIME types) work regardless of how many files exist on disk.
python3 - "$ROOT/config/mime" "$MIME_CATALOG" <<'PY'
import json, pathlib, sys, xml.etree.ElementTree as ET
mime_dir, output = map(pathlib.Path, sys.argv[1:])
ns = {'m': 'http://www.freedesktop.org/standards/shared-mime-info'}
items = {}
for path in sorted(mime_dir.glob('*.xml')):
    root = ET.parse(path).getroot()
    for node in root.findall('m:mime-type', ns):
        mime = node.attrib.get('type')
        if not mime:
            continue
        globs = [g.attrib['pattern'] for g in node.findall('m:glob', ns) if g.attrib.get('pattern')]
        item = items.setdefault(mime, {'mime': mime, 'globs': []})
        item['globs'].extend(x for x in globs if x not in item['globs'])
output.write_text(json.dumps(sorted(items.values(), key=lambda x: x['mime']), indent=2) + '\n')
print(f"Catalogued {len(items)} MIME types")
PY

cat > "$APP_HOME/export-glyph.py" <<'PY'
import fontforge, sys
font_path, code_hex, output = sys.argv[1:]
font = fontforge.open(font_path)
codepoint = int(code_hex, 16)
if codepoint not in font:
    raise SystemExit(f"Glyph U+{code_hex} is absent from {font_path}")
font[codepoint].export(output)
font.close()
PY

cat > "$WORKER" <<'PY'
#!/usr/bin/env python3
import configparser
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

HOME = pathlib.Path.home()
DATA_HOME = pathlib.Path(os.environ.get('XDG_DATA_HOME', HOME / '.local/share'))
CONFIG_HOME = pathlib.Path(os.environ.get('XDG_CONFIG_HOME', HOME / '.config'))
CACHE_HOME = pathlib.Path(os.environ.get('XDG_CACHE_HOME', HOME / '.cache')) / 'fedora-setup/dev-icons'
APP_HOME = DATA_HOME / 'fedora-setup/dev-icons'
ICON_ROOT = DATA_HOME / 'icons/hicolor/scalable/mimetypes'
MIME_HOME = DATA_HOME / 'mime'
OVERRIDE = MIME_HOME / 'packages/fedora-setup-dev-icons.xml'
STATE_FILE = APP_HOME / 'state.json'
STYLE_FILE = CONFIG_HOME / 'fedora-setup/dev-icons-style'
CATALOG = APP_HOME / 'mimes.json'
GLYPHS = CACHE_HOME / 'glyphnames.json'
FONT = next(CACHE_HOME.glob('nerd-fonts-*/SymbolsNerdFont-Regular.ttf'), None)
EXPORTER = APP_HOME / 'export-glyph.py'
DEFAULT_COLOR = '#5E5E5E'

# Only true semantic exceptions live here. Normal languages/tools are resolved
# from MIME/glob names against Nerd Fonts automatically.
ALIASES = {
    'c-sharp': 'csharp', 'c_sharp': 'csharp', 'cs': 'csharp',
    'f-sharp': 'fsharp', 'f_sharp': 'fsharp', 'fs': 'fsharp',
    'dot-net': 'dotnet', 'dot_net': 'dotnet',
    'c++': 'cpp', 'cxx': 'cpp', 'cplusplus': 'cpp',
    'objective-c': 'objective_c', 'objectivec': 'objective_c',
    'visual-basic': 'visual_basic', 'vb': 'visual_basic',
    'yml': 'yaml', 'ps1': 'powershell', 'sh': 'bash',
}

BRAND_COLORS = {
    'csharp': '#68217A', 'fsharp': '#378BBA', 'dotnet': '#512BD4',
    'python': '#3776AB', 'go': '#00ADD8', 'rust': '#CE412B',
    'java': '#E76F00', 'kotlin': '#7F52FF', 'scala': '#DC322F',
    'php': '#777BB4', 'ruby': '#CC342D', 'javascript': '#F7DF1E',
    'typescript': '#3178C6', 'swift': '#F05138', 'dart': '#0175C2',
    'docker': '#2496ED', 'podman': '#892CA0', 'kubernetes': '#326CE5',
    'terraform': '#844FBA', 'git': '#F05032', 'html5': '#E34F26',
    'css3': '#1572B6', 'sass': '#CC6699', 'graphql': '#E10098',
}

PREFIXES = ('nf-dev-', 'nf-seti-', 'nf-custom-', 'nf-cod-', 'nf-md-', 'nf-fa-', 'nf-linux-')


def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout.strip()


def load_json(path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def style():
    try:
        value = STYLE_FILE.read_text().strip()
    except FileNotFoundError:
        return ('monochrome', DEFAULT_COLOR)
    if value.startswith('custom:') and re.fullmatch(r'#[0-9A-Fa-f]{6}', value[7:]):
        return ('custom', value[7:])
    if value == 'brand':
        return ('brand', DEFAULT_COLOR)
    return ('monochrome', DEFAULT_COLOR)


def tokens_for(item):
    mime = item['mime'].lower()
    subtype = mime.split('/', 1)[-1]
    raw = [subtype, re.sub(r'^(x-|vnd\.)', '', subtype)]
    for glob in item.get('globs', []):
        value = glob.lower().replace('*', '').lstrip('.')
        if value:
            raw.extend([value, value.rsplit('.', 1)[-1]])
    tokens = []
    for value in raw:
        variants = [value, value.replace('-', '_'), value.replace('_', '-'), re.sub(r'[^a-z0-9+_-]+', '_', value)]
        variants.extend(re.split(r'[-_.+]+', value))
        for token in variants:
            token = token.strip('_-.')
            if not token or token in {'x', 'vnd', 'application', 'text', 'file'}:
                continue
            alias = ALIASES.get(token, token)
            for candidate in (alias, alias.replace('-', '_'), alias.replace('_', '-')):
                if candidate and candidate not in tokens:
                    tokens.append(candidate)
    return tokens


def find_glyph(item, glyphs):
    for token in tokens_for(item):
        for prefix in PREFIXES:
            name = prefix + token
            if name in glyphs:
                return name, glyphs[name]['code'], token
    return None


def desktop_icon(mime):
    desktop = run('xdg-mime', 'query', 'default', mime)
    if not desktop:
        return None
    roots = [
        DATA_HOME / 'applications',
        HOME / '.local/share/flatpak/exports/share/applications',
        pathlib.Path('/var/lib/flatpak/exports/share/applications'),
        pathlib.Path('/usr/local/share/applications'),
        pathlib.Path('/usr/share/applications'),
    ]
    for root in roots:
        path = root / desktop
        if not path.is_file():
            continue
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            parser.read(path, encoding='utf-8')
            icon = parser.get('Desktop Entry', 'Icon', fallback='').strip()
        except (configparser.Error, OSError):
            continue
        if icon:
            # Absolute icons are not theme names and cannot be used in the MIME
            # icon map reliably. Theme icon names need no copying at all.
            return icon if not os.path.isabs(icon) else None
    return None


def desired(item, glyphs, style_name, custom_color):
    glyph = find_glyph(item, glyphs)
    if glyph:
        name, code, token = glyph
        color = custom_color
        if style_name == 'brand':
            color = BRAND_COLORS.get(token, DEFAULT_COLOR)
        return {'source': 'nerd-font', 'icon': item['mime'].replace('/', '-'), 'glyph': name, 'code': code, 'color': color}
    app_icon = desktop_icon(item['mime'])
    if app_icon:
        return {'source': 'application', 'icon': app_icon}
    return {'source': 'generic', 'icon': None}


def render_nerd_icon(mime, value):
    if FONT is None:
        raise RuntimeError('Nerd Fonts Symbols Only font is missing')
    ICON_ROOT.mkdir(parents=True, exist_ok=True)
    icon_name = mime.replace('/', '-')
    target = ICON_ROOT / f'{icon_name}.svg'
    symbolic = ICON_ROOT / f'{icon_name}-symbolic.svg'
    with tempfile.TemporaryDirectory() as temp:
        raw = pathlib.Path(temp) / 'raw.svg'
        subprocess.run(['fontforge', '-quiet', '-script', str(EXPORTER), str(FONT), value['code'], str(raw)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        content = raw.read_text()
    content = content.replace('<svg ', f'<svg style="fill:{value["color"]}" ', 1)
    target.write_text(content)
    symbolic.write_text(content)


def remove_owned_icon(mime):
    icon_name = mime.replace('/', '-')
    for suffix in ('.svg', '-symbolic.svg'):
        path = ICON_ROOT / f'{icon_name}{suffix}'
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def write_override(resolved):
    root = ET.Element('mime-info', {'xmlns': 'http://www.freedesktop.org/standards/shared-mime-info'})
    for mime, value in sorted(resolved.items()):
        if value['source'] == 'generic':
            continue
        node = ET.SubElement(root, 'mime-type', {'type': mime})
        ET.SubElement(node, 'icon', {'name': value['icon']})
    ET.indent(root, space='  ')
    content = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding='unicode') + '\n'
    old = OVERRIDE.read_text() if OVERRIDE.exists() else None
    if old == content:
        return False
    OVERRIDE.parent.mkdir(parents=True, exist_ok=True)
    OVERRIDE.write_text(content)
    return True


def reconcile():
    catalog = load_json(CATALOG, [])
    glyphs = load_json(GLYPHS, {})
    old_state = load_json(STATE_FILE, {})
    style_name, custom_color = style()
    new_state = {}
    changed_icons = 0

    for item in catalog:
        mime = item['mime']
        value = desired(item, glyphs, style_name, custom_color)
        previous = old_state.get(mime)
        new_state[mime] = value
        if previous == value:
            continue
        if value['source'] == 'nerd-font':
            render_nerd_icon(mime, value)
            changed_icons += 1
        elif previous and previous.get('source') == 'nerd-font':
            remove_owned_icon(mime)
            changed_icons += 1

    # Remove stale icons only when they were generated by this resolver.
    for mime, previous in old_state.items():
        if mime not in new_state and previous.get('source') == 'nerd-font':
            remove_owned_icon(mime)
            changed_icons += 1

    override_changed = write_override(new_state)
    if override_changed:
        subprocess.run(['update-mime-database', str(MIME_HOME)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if changed_icons and shutil_which('gtk-update-icon-cache'):
        subprocess.run(['gtk-update-icon-cache', '-f', '-t', str(DATA_HOME / 'icons/hicolor')], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    APP_HOME.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(new_state, indent=2, sort_keys=True) + '\n')
    counts = {key: sum(1 for x in new_state.values() if x['source'] == key) for key in ('nerd-font', 'application', 'generic')}
    print(f"dev-mime-icons: {len(new_state)} MIME types; {counts['nerd-font']} Nerd Font, "
          f"{counts['application']} application fallback, {counts['generic']} generic; {changed_icons} icon changes")


def shutil_which(name):
    from shutil import which
    return which(name)


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'reconcile'
    if command != 'reconcile':
        raise SystemExit(f'Unknown command: {command}')
    reconcile()
PY
chmod +x "$WORKER"

cat > "$SYSTEMD_HOME/dev-mime-icons.service" <<EOF
[Unit]
Description=Reconcile developer MIME icons

[Service]
Type=oneshot
ExecStart=$WORKER reconcile
EOF

cat > "$SYSTEMD_HOME/dev-mime-icons.path" <<EOF
[Unit]
Description=Watch default application changes for developer MIME icons

[Path]
PathChanged=$CONFIG_HOME/mimeapps.list
PathChanged=$DATA_HOME/applications/mimeapps.list
Unit=dev-mime-icons.service

[Install]
WantedBy=default.target
EOF

STYLE_DIR="$CONFIG_HOME/fedora-setup"
mkdir -p "$STYLE_DIR"
[ -f "$STYLE_DIR/dev-icons-style" ] || printf '%s\n' 'monochrome' > "$STYLE_DIR/dev-icons-style"

systemctl --user daemon-reload
systemctl --user enable --now dev-mime-icons.path >/dev/null

log "Resolving developer MIME icons"
"$WORKER" reconcile

ok "Dynamic developer MIME icons installed"
echo "The resolver watches MIME default-application changes, not project files."
echo "Nerd Font icons always have priority over default-application icons."
echo "Run './install.sh dev-icons-color' to change the generated Nerd Font icon style."
