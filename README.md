# Fedora Setup

Modular Fedora Workstation bootstrap for a .NET/Aspire development machine.

## Main choices

- Podman instead of Docker Engine; rootless/daemonless by default.
- .NET 10 SDK from Fedora repositories.
- Aspire CLI with `ASPIRE_CONTAINER_RUNTIME=podman` and Linux certificate trust path.
- Node.js/npm with a user-owned npm prefix, then OpenAI Codex CLI.
- Zsh + Oh My Zsh with Starship as the default prompt.
- JetBrainsMono, FiraCode and Meslo Nerd Fonts installed per-user for terminal/IDE glyph support.
- Powerlevel10k is kept as an optional alternative in `optional/powerlevel10k.sh`.
- GNOME, Nautilus, Flatpak apps, RPM Fusion codecs and optional NVIDIA drivers.
- Local user MIME pack for developer formats and selected Windows formats.
- No automatic reboot.

## Run everything

```bash
chmod +x install.sh modules/*.sh diagnostics/*.sh optional/*.sh
./install.sh
```

## Run selected modules

```bash
./install.sh 05-podman 06-dotnet 07-aspire
./install.sh 09-zsh 10-nerd-fonts 11-starship
./install.sh 16-mime
```


## Nerd Fonts

The default install adds three Nerd Font families for the current user:

- **JetBrainsMono Nerd Font** — recommended default for the terminal and IDE console.
- **FiraCode Nerd Font** — alternative programming font with ligatures.
- **Meslo Nerd Font** — useful with the optional Powerlevel10k prompt.

They are installed under:

```text
~/.local/share/fonts/NerdFonts/
```

The installer prefers the compact Nerd Fonts `tar.xz` release archives and falls back to ZIP when needed. The font cache is refreshed automatically with `fc-cache`. The setup deliberately does not change the GNOME interface font or force a terminal profile font. Select **JetBrainsMono Nerd Font** (preferably a Mono variant when your terminal exposes one) in the terminal settings.

To install only a subset, override `NERD_FONTS`:

```bash
NERD_FONTS="JetBrainsMono FiraCode" ./install.sh 10-nerd-fonts
```

## Zsh and prompt

Starship is selected by default through:

```bash
export FEDORA_PROMPT_ENGINE="starship"
```

The repository includes a development-oriented configuration at:

```text
config/starship/starship.toml
```

On first install it is copied to:

```text
~/.config/starship.toml
```

If a Starship configuration already exists, it is left untouched.

To install and switch to Powerlevel10k instead:

```bash
./optional/powerlevel10k.sh
```

After opening a new terminal:

```bash
p10k configure
```

To switch back to Starship:

```bash
sed -i 's/FEDORA_PROMPT_ENGINE="powerlevel10k"/FEDORA_PROMPT_ENGINE="starship"/' ~/.zshenv
exec zsh
```

## Important after install

Log out and log back in (or reboot) so the default shell/session changes are applied. If NVIDIA packages were installed, allow `akmods` to finish before rebooting.

Then:

```bash
aspire doctor
./diagnostics/check-environment.sh
./diagnostics/check-mime.sh
```

## MIME pack

Installed per-user into:

```text
~/.local/share/mime/packages/
```

The catalog is split by language/category in `config/mime/` and covers .NET, Go, Python, PHP, Node.js/JavaScript/TypeScript, JVM languages, C/C++/Rust/Zig/Swift, scripting languages, SQL/data formats, API/infra formats, containers/Podman, build tools, AI/template formats, and selected Windows-specific formats.

The setup deliberately does **not** force a default editor. Once MIME definitions are installed, Nautilus can keep a separate default application for each MIME type:

1. Right-click a file.
2. Choose **Open With**.
3. Select Rider, VS Code, Zed, GNOME Text Editor, or another application.
4. Choose **Set as Default** when desired.

This means choosing Rider for `text/x-csharp` does not also change Python, Go, PHP, or generic text files. Existing Fedora/shared-mime-info types are extended where appropriate instead of inventing incompatible duplicates.

`windows-extra.xml` remains intentionally selective: legacy aliases such as multiple MIME names for MP3/PNG/AVI are left to Fedora/shared-mime-info.

Run the catalog diagnostic with:

```bash
./diagnostics/check-mime.sh
```

To see which application is currently the default for the main developer MIME types:

```bash
./diagnostics/check-mime-defaults.sh
```

## Podman socket

`podman.socket` is intentionally not enabled. Aspire can use Podman directly. If a future tool requires a Docker-compatible API, enable it explicitly:

```bash
systemctl --user enable --now podman.socket
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
```
