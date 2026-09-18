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
SYSTEM_PYTHON="/usr/bin/python3"

if ! "$SYSTEM_PYTHON" -c 'import fontTools' >/dev/null 2>&1; then
  require_sudo
  install_packages_if_missing python3-fonttools
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
"$SYSTEM_PYTHON" - "$ROOT/config/mime" "$MIME_CATALOG" <<'PY'
import json, os, pathlib, sys, xml.etree.ElementTree as ET
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

# These MIME types already belong to shared-mime-info. Read their globs from
# the installed database instead of redefining them in config/mime/*.xml.
standard_mimes = {
    'application/json',
    'application/sql',
    'application/xhtml+xml',
    'application/xml',
    'application/yaml',
    'image/svg+xml',
    'text/css',
    'text/html',
}
data_home = pathlib.Path(os.environ.get('XDG_DATA_HOME', pathlib.Path.home() / '.local/share'))
data_dirs = [data_home, *(pathlib.Path(x) for x in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if x)]
for data_dir in data_dirs:
    globs_file = data_dir / 'mime/globs2'
    if not globs_file.is_file():
        continue
    for line in globs_file.read_text(errors='replace').splitlines():
        if not line or line.startswith('#'):
            continue
        parts = line.split(':', 3)
        if len(parts) < 3 or parts[1] not in standard_mimes:
            continue
        mime, glob = parts[1], parts[2]
        item = items.setdefault(mime, {'mime': mime, 'globs': []})
        if glob not in item['globs']:
            item['globs'].append(glob)
output.write_text(json.dumps(sorted(items.values(), key=lambda x: x['mime']), indent=2) + '\n')
print(f"Catalogued {len(items)} MIME types")
PY

cat > "$APP_HOME/export-glyph.py" <<'PY'
from pathlib import Path
import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

font_path, code_hex, output = sys.argv[1:]
codepoint = int(code_hex, 16)
font = TTFont(font_path)
glyph_name = font.getBestCmap().get(codepoint)
if glyph_name is None:
    raise SystemExit(f"Glyph U+{code_hex} is absent from {font_path}")

glyph_set = font.getGlyphSet()
glyph = glyph_set[glyph_name]
bounds_pen = BoundsPen(glyph_set)
glyph.draw(bounds_pen)
if bounds_pen.bounds is None:
    raise SystemExit(f"Glyph U+{code_hex} has no outline in {font_path}")

path_pen = SVGPathPen(glyph_set)
glyph.draw(path_pen)
path = path_pen.getCommands()
x_min, y_min, x_max, y_max = bounds_pen.bounds
width = max(1, x_max - x_min)
height = max(1, y_max - y_min)
svg = (
    f'<svg xmlns="http://www.w3.org/2000/svg" '
    f'viewBox="{x_min} {-y_max} {width} {height}">'
    f'<path transform="scale(1,-1)" d="{path}"/>'
    '</svg>\n'
)
Path(output).write_text(svg)
font.close()
PY

cat > "$WORKER" <<'PY'
#!/usr/bin/python3
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

from fontTools.ttLib import TTFont

HOME = pathlib.Path.home()
DATA_HOME = pathlib.Path(os.environ.get('XDG_DATA_HOME', HOME / '.local/share'))
CONFIG_HOME = pathlib.Path(os.environ.get('XDG_CONFIG_HOME', HOME / '.config'))
CACHE_HOME = pathlib.Path(os.environ.get('XDG_CACHE_HOME', HOME / '.cache')) / 'fedora-setup/dev-icons'
APP_HOME = DATA_HOME / 'fedora-setup/dev-icons'
HICOLOR_ROOT = DATA_HOME / 'icons/hicolor/scalable/mimetypes'
MIME_HOME = DATA_HOME / 'mime'
OVERRIDE = MIME_HOME / 'packages/fedora-setup-dev-icons.xml'
STATE_FILE = APP_HOME / 'state.json'
STYLE_FILE = CONFIG_HOME / 'fedora-setup/dev-icons-style'
CATALOG = APP_HOME / 'mimes.json'
GLYPHS = CACHE_HOME / 'glyphnames.json'
FONT = next(CACHE_HOME.glob('nerd-fonts-*/SymbolsNerdFont-Regular.ttf'), None)
EXPORTER = APP_HOME / 'export-glyph.py'
SYSTEM_PYTHON = pathlib.Path('/usr/bin/python3')
DEFAULT_COLOR = '#5E5E5E'
BRAND_FALLBACK_COLORS = ('#64B5F6', '#81C784', '#FFB74D', '#CE93D8', '#4DD0E1', '#FF8A80', '#AED581', '#F48FB1')


def font_codepoints():
    if FONT is None:
        return set()
    font = TTFont(FONT)
    try:
        return set(font.getBestCmap())
    finally:
        font.close()


FONT_CODEPOINTS = font_codepoints()

# Only true semantic exceptions live here. Normal languages/tools are resolved
# from MIME/glob names against Nerd Fonts automatically.
ALIASES = {
    'c-sharp': 'csharp', 'c_sharp': 'csharp', 'cs': 'csharp',
    'f-sharp': 'fsharp', 'f_sharp': 'fsharp', 'fs': 'fsharp',
    'dot-net': 'dotnet', 'dot_net': 'dotnet',
    'dockerfile': 'docker', 'containerfile': 'docker', 'container': 'docker',
    'c++': 'cpp', 'cxx': 'cpp', 'cplusplus': 'cpp',
    'objective-c': 'objectivec', 'objective_c': 'objectivec',
    'visual-basic': 'visualbasic', 'visual_basic': 'visualbasic', 'vb': 'visualbasic', 'vbnet': 'visualbasic',
    'jsx': 'react', 'cjsx': 'react', 'mdx': 'markdown',
    'cshtml': 'dotnet', 'razor': 'dotnet', 'vbhtml': 'dotnet',
    'msbuild': 'dotnet',
    'chdr': 'c', 'python3': 'python', 'pyi': 'python',
    'dotenv': 'config', 'earthfile': 'docker', 'procfile': 'server',
    'protobuf': 'protocol', 'proto': 'protocol',
    'duckdb': 'sqlite', 'sql': 'sqldeveloper',
    'yml': 'yaml', 'ps1': 'powershell', 'sh': 'bash',
}

GLYPH_OVERRIDES = {
    'application/geo+json': ('cod-json', 'json'),
    'application/json': ('cod-json', 'json'),
    'application/json5': ('cod-json', 'json'),
    'application/opensearchdescription+xml': ('md-xml', 'xml'),
    'application/xhtml+xml': ('md-xml', 'xml'),
    'application/xml': ('md-xml', 'xml'),
    'application/x-ipynb+json': ('cod-json', 'json'),
    'application/x-jetbrains-dotsettings+xml': ('dev-rider', 'rider'),
    'application/x-jsonc': ('cod-json', 'json'),
    'application/x-ndjson': ('cod-json', 'json'),
    'application/x-nuspec+xml': ('md-xml', 'xml'),
    'application/xaml+xml': ('md-xml', 'xml'),
}

BRAND_COLORS = {
    'csharp': '#C77DFF', 'fsharp': '#5DADE2', 'dotnet': '#8B5CF6',
    'python': '#4EA1D3', 'go': '#00ADD8', 'rust': '#F0785A',
    'bash': '#4EAA25',
    'json': '#F9C74F', 'markdown': '#5DADE2', 'yaml': '#FF6B6B',
    'xml': '#F39C12', 'config': '#A3E635', 'editorconfig': '#FF6B6B',
    'project': '#A78BFA', 'rider': '#FF5C93',
    'java': '#E76F00', 'kotlin': '#B47CFF', 'scala': '#FF5C5C',
    'php': '#9B9BEF', 'ruby': '#FF6B6B', 'javascript': '#F7DF1E',
    'typescript': '#4F9DE8', 'swift': '#F05138', 'dart': '#29B6F6',
    'docker': '#2496ED', 'podman': '#C77DFF', 'kubernetes': '#5B8DEF',
    'terraform': '#A78BFA', 'git': '#F05032', 'html5': '#E34F26',
    'css3': '#42A5F5', 'sass': '#E57AB1', 'graphql': '#FF5CC8',
}

PREFIXES = ('dev-', 'seti-', 'custom-', 'cod-', 'md-', 'fa-', 'linux-', 'oct-', 'fae-')


def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout.strip()


def active_icon_theme():
    value = run('gsettings', 'get', 'org.gnome.desktop.interface', 'icon-theme').strip("'\"")
    return value if re.fullmatch(r'[A-Za-z0-9._+-]+', value) else None


def ensure_theme_overlay(theme):
    theme_root = DATA_HOME / 'icons' / theme
    target = theme_root / 'index.theme'
    data_dirs = [pathlib.Path(x) for x in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if x]
    source = next((root / 'icons' / theme / 'index.theme' for root in data_dirs
                   if (root / 'icons' / theme / 'index.theme').is_file()), None)
    if source is not None:
        content = source.read_text()
        if not target.is_file() or target.read_text() != content:
            theme_root.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
    return theme_root


def icon_targets(icon_name):
    targets = [
        (HICOLOR_ROOT / f'{icon_name}.svg', HICOLOR_ROOT / f'{icon_name}-symbolic.svg'),
    ]
    theme = active_icon_theme()
    if theme and theme.lower() != 'hicolor':
        theme_root = ensure_theme_overlay(theme)
        targets.append((
            theme_root / 'scalable/mimetypes' / f'{icon_name}.svg',
            theme_root / 'symbolic/mimetypes' / f'{icon_name}-symbolic.svg',
        ))
    return targets


def icons_complete(icon_name):
    return all(target.is_file() and symbolic.is_file() for target, symbolic in icon_targets(icon_name))


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
    override = GLYPH_OVERRIDES.get(item['mime'])
    if override is not None and override[0] in glyphs:
        name, token = override
        code = glyphs[name]['code']
        if int(code, 16) in FONT_CODEPOINTS:
            return name, code, token
    for token in tokens_for(item):
        for prefix in PREFIXES:
            name = prefix + token
            if name in glyphs:
                code = glyphs[name]['code']
                if int(code, 16) in FONT_CODEPOINTS:
                    return name, code, token
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
            color = BRAND_COLORS.get(token)
            if color is None:
                digest = hashlib.sha256(token.encode()).digest()[0]
                color = BRAND_FALLBACK_COLORS[digest % len(BRAND_FALLBACK_COLORS)]
        return {'source': 'nerd-font', 'icon': item['mime'].replace('/', '-'), 'glyph': name, 'code': code, 'color': color}
    app_icon = desktop_icon(item['mime'])
    if app_icon:
        return {'source': 'application', 'icon': app_icon}
    return {'source': 'generic', 'icon': None}


def render_nerd_icon(mime, value):
    if FONT is None:
        raise RuntimeError('Nerd Fonts Symbols Only font is missing')
    icon_name = mime.replace('/', '-')
    with tempfile.TemporaryDirectory() as temp:
        raw = pathlib.Path(temp) / 'raw.svg'
        subprocess.run([str(SYSTEM_PYTHON), str(EXPORTER), str(FONT), value['code'], str(raw)], check=True,
                       stdout=subprocess.DEVNULL)
        content = raw.read_text()
    content = content.replace('<svg ', f'<svg style="fill:{value["color"]}" ', 1)
    for target, symbolic in icon_targets(icon_name):
        target.parent.mkdir(parents=True, exist_ok=True)
        symbolic.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        symbolic.write_text(content)


def remove_owned_icon(mime):
    icon_name = mime.replace('/', '-')
    for target, symbolic in icon_targets(icon_name):
        for path in (target, symbolic):
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
            if value['source'] == 'nerd-font' and not icons_complete(value['icon']):
                render_nerd_icon(mime, value)
                changed_icons += 1
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
    theme = active_icon_theme()
    if theme and theme.lower() != 'hicolor' and shutil_which('gtk-update-icon-cache'):
        theme_root = ensure_theme_overlay(theme)
        subprocess.run(['gtk-update-icon-cache', '-f', '-t', str(theme_root)], check=False,
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
