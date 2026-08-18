# Fedora Setup

Modular Fedora Workstation bootstrap for a .NET/Aspire development machine.

## Main choices

- Podman instead of Docker Engine; rootless/daemonless by default.
- Latest stable .NET 10 SDK from Microsoft, installed system-wide and updated weekly by a systemd timer.
- Aspire CLI installed as the `Aspire.Cli` .NET global tool.
- Aspire configured for Podman and Linux development-certificate trust.
- Node.js/npm with a user-owned npm prefix, then OpenAI Codex CLI.
- Zsh + Oh My Zsh with Starship as the default prompt.
- Powerlevel10k is kept as an optional alternative in `optional/powerlevel10k.sh`.
- Nerd Fonts: JetBrainsMono, FiraCode and MesloLGS NF.
- GNOME, Nautilus, Flatpak apps, RPM Fusion codecs and optional NVIDIA drivers.
- Local user MIME catalog for development languages/tools and selected Windows formats.
- No automatic reboot.

## Run everything

```bash
chmod +x install.sh modules/*.sh diagnostics/*.sh optional/*.sh
./install.sh
```

The full installer is non-interactive between modules. It may request the sudo password once at the beginning, then continues automatically.

## Run selected modules

Module numbers are only installation order. Prefer stable names:

```bash
./install.sh podman dotnet aspire
./install.sh zsh nerd-fonts starship
./install.sh mime
```

List all current modules:

```bash
./install.sh --list
```

Old numbered names are also resolved by semantic name when possible, but scripts and documentation should use stable names.

## System .NET SDK

.NET is installed from Microsoft's official release binaries into:

```text
/usr/local/share/dotnet
```

`/usr/local/bin/dotnet` points to that installation. The
`dotnet-sdk-update.timer` systemd timer checks weekly for the latest stable SDK
in the .NET 10 channel. It stages and verifies a complete new installation
before replacing the previous version, so obsolete SDK feature bands do not
accumulate.

Run an update immediately or inspect the timer with:

```bash
sudo systemctl start dotnet-sdk-update.service
systemctl status dotnet-sdk-update.timer
```

In Rider, use `/usr/local/bin/dotnet` as the .NET CLI executable and disable
automatic SDK downloads.

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

Then open a new terminal and run:

```bash
p10k configure
```

To switch back to Starship:

```bash
sed -i 's/FEDORA_PROMPT_ENGINE="powerlevel10k"/FEDORA_PROMPT_ENGINE="starship"/' ~/.zshenv
exec zsh
```

## Aspire

Aspire is installed through the official .NET global tool package:

```bash
dotnet tool install -g Aspire.Cli
```

The setup adds:

```bash
export ASPIRE_CONTAINER_RUNTIME=podman
```

The development certificate is managed by Aspire without globally overriding
`SSL_CERT_DIR`, because that variable can break applications with bundled TLS
libraries (including Steam).

Certificate refresh is executed non-interactively:

```bash
aspire certs clean --non-interactive --nologo
aspire certs trust --non-interactive --nologo
```

## MIME pack

MIME definitions are stored as separate files in:

```text
config/mime/
```

The `mime` module installs **all** XML files from that directory into:

```text
~/.local/share/mime/packages/
```

Run or reapply it with:

```bash
./install.sh mime
```

Before installing, the module removes only previous `fedora-setup-*.xml` files, so deleted or renamed definitions do not remain stale.

GNOME normally classifies every zero-byte file as `application/x-zerosize`,
ignoring its extension for application selection. The MIME module installs a
small handler for that special type. It determines the type from the filename
and opens the original empty file with the application already configured for
that type—for example, an empty `.cs` uses the default C# application and an
empty `.md` uses the default Markdown application.

The Windows list is intentionally not copied verbatim: legacy aliases such as multiple MIME names for MP3/PNG/AVI are left to Fedora/shared-mime-info. `windows-extra.xml` focuses on Windows-specific formats useful for Nautilus recognition.

## Nerd Fonts

The `nerd-fonts` module installs user-local fonts into:

```text
~/.local/share/fonts/NerdFonts
```

Default families:

- JetBrainsMono Nerd Font
- FiraCode Nerd Font
- MesloLGS NF (recommended for Powerlevel10k)

Run:

```bash
./install.sh nerd-fonts
```

Install only a subset:

```bash
NERD_FONTS="JetBrainsMono FiraCode" ./install.sh nerd-fonts
```

## Podman socket

`podman.socket` is intentionally not enabled by default. Aspire can use Podman directly. If a future tool specifically requires a Docker-compatible API:

```bash
systemctl --user enable --now podman.socket
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
```

## Diagnostics

After installation:

```bash
aspire doctor
./diagnostics/check-environment.sh
./diagnostics/check-mime.sh
./diagnostics/check-mime-defaults.sh
```

## Important after install

Log out and log back in (or reboot) so the default shell/session changes are applied. If NVIDIA packages were installed, allow `akmods` to finish before rebooting.
