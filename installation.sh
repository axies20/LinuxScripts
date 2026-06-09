# Check for sudo
if ! command -v sudo &> /dev/null; then
    echo "sudo is not installed. Please install sudo and try again."
    exit 1
fi

# Remove power save for speakers
line='options snd_hda_intel power_save=0 power_save_controller=N'
conf='/etc/modprobe.d/snd_hda_intel.conf'
grep -qxF "$line" "$conf" || echo "$line" | sudo tee -a "$conf" >/dev/null


# Set volume step
echo "Setting volume step..."
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2

# Check volume step
echo "Checking volume step..."
gsettings get org.gnome.settings-daemon.plugins.media-keys volume-step


# Update system
echo "Updating system..."
sudo dnf upgrade --refresh -y

# Install RPM Fusion repositories for free and non-free software
fedora_ver="$(rpm -E %fedora)"
echo "Installing RPM Fusion repositories..."
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm

# Import 1Password GPG key
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'


sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

# Update system
echo "Updating system..."
sudo dnf upgrade --refresh -y

# Install necessary tools
echo "Installing necessary tools..."
sudo dnf clean all
sudo dnf install -y \
    git \
    gedit \
    curl \
    1password \
    wget \
    vim \
    nano \
    net-tools \
    zip \
    unzip \
    tar \
    jq \
    ripgrep \
    fd-find \
    fzf \
    bat \
    tmux \
    git-delta \
    code \
    yq \
    openssl-devel \
    libicu \
    gnome-tweaks \
    steam \
    fastfetch \
    java-latest-openjdk \
    ca-certificates \
    p11-kit \
    p11-kit-trust \
    nss-tools \
    openssl \
    powerline-fonts

sudo dnf install -y eza || sudo dnf install -y exa || true

#install certs
echo "Installing CA certificates..."
sudo update-ca-trust
sudo mkdir -p /etc/ssl/certs
sudo ln -sf /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

#install docker
sudo dnf remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine


sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

echo "Installing kernel packages"
sudo dnf install -y \
    dnf-plugins-core \
    kernel-devel \
    kernel-headers

echo "Installing nautilus extensions"
sudo dnf install -y \
    nautilus-python \
    nautilus-extensions \
    nautilus-gtkhash

echo "Installing Codec"
# Media codecs (RPM-based apps)
sudo dnf group install -y multimedia
sudo dnf swap -y 'ffmpeg-free' 'ffmpeg' --allowerasing
sudo dnf upgrade -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
sudo dnf group install -y sound-and-video
#OpenH264 for Firefox
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
sudo dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264


# NVIDIA drivers / VA-API tooling
if lspci | grep -Eiq 'nvidia.*(vga|3d|display)|(vga|3d|display).*nvidia'; then
    echo "NVIDIA GPU detected. Installing NVIDIA drivers and VA-API tooling..."

    sudo dnf install -y \
        kernel-devel \
        kernel-headers \
        gcc \
        make \
        akmod-nvidia \
        xorg-x11-drv-nvidia \
        xorg-x11-drv-nvidia-cuda \
        nvidia-settings \
        nvidia-modprobe \
        nvidia-persistenced \
        xorg-x11-drv-nvidia-power
else
    echo "No NVIDIA GPU detected. Skipping NVIDIA drivers."
fi


echo "Installing Brave"
curl -fsS https://dl.brave.com/install.sh | sh


# Install .NET using the official script
echo "Installing .NET SDK and Runtime..."
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel LTS
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel STS

grep -qxF 'export DOTNET_ROOT=$HOME/.dotnet' ~/.bashrc || echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
grep -qxF 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' ~/.bashrc || echo 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' >> ~/.bashrc

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"

dotnet --version
dotnet tool install -g dotnet-ef
dotnet tool install -g dotnet-format
dotnet tool install -g coverlet.console
dotnet tool install -g dotnet-reportgenerator-globaltool

#install aspire
curl -sSL https://aspire.dev/install.sh | bash
aspire certs clean
aspire certs trust

# Install GNOME extensions by UUID
echo "Installing GNOME extensions..."
extensions=(
    blur-my-shell@aunetx
    dash-to-dock@micxgx.gmail.com
    gtk4-ding@smedius.gitlab.com
    clipboard-indicator@tudmotu.com
    osd-volume-number@deminder
    search-light@icedman.github.com
    fullscreen-avoider@noobsai.github.com
    gnome-fuzzy-app-search@gnome-shell-extensions.Czarlie.gitlab.com
    gamebar-overlay@dekotale.github.io
)
for extension in "${extensions[@]}"
do
    VERSION_TAG=$(curl -Lfs "https://extensions.gnome.org/extension-query/?search=${extension}" | jq '.extensions[0] | .shell_version_map | map(.pk) | max')
    wget -O ${extension}.zip "https://extensions.gnome.org/download-extension/${extension}.shell-extension.zip?version_tag=$VERSION_TAG"
    gnome-extensions install --force --quiet ${extension}.zip
    if ! gnome-extensions list | grep --quiet ${extension}; then
        busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions org.gnome.Shell.Extensions InstallRemoteExtension s ${extension}
    fi
    gnome-extensions enable ${extension}
    rm ${extension}.zip
done



echo "Configuring Flathub (GPG-safe)..."

FLATHUB_KEY="/etc/pki/flatpak/flathub.gpg"
FLATHUB_REMOTE="flathub"
FLATHUB_REPO="https://dl.flathub.org/repo/flathub.flatpakrepo"

# Install flatpak if missing
if ! command -v flatpak &>/dev/null; then
    sudo dnf install -y flatpak
fi

# Ensure GPG key exists
if [ ! -f "$FLATHUB_KEY" ]; then
    echo "Installing Flathub GPG key..."
    sudo mkdir -p /etc/pki/flatpak
    sudo curl -fsSL https://dl.flathub.org/repo/flathub.gpg \
        -o "$FLATHUB_KEY"
fi

# Add Flathub remote with GPG verification
if ! flatpak remotes --system --columns=name | grep -qx "$FLATHUB_REMOTE"; then
    echo "Adding Flathub remote..."
    sudo flatpak remote-add \
        --system \
        --if-not-exists \
        --gpg-import="$FLATHUB_KEY" \
        "$FLATHUB_REMOTE" "$FLATHUB_REPO"
else
    echo "Flathub remote already exists."
fi

# Enforce GPG verification (just in case)
sudo flatpak remote-modify --system --gpg-verify=true "$FLATHUB_REMOTE"


echo "Installing Freedesktop Flatpak runtime and add-ons..."



# Install additional applications via Flatpak
echo "Installing additional applications..."
flatpak install -y flathub com.mattjakeman.ExtensionManager
flatpak install -y flathub org.telegram.desktop
flatpak install -y flathub org.qbittorrent.qBittorrent
flatpak install -y flathub com.vysp3r.ProtonPlus
flatpak install -y flathub com.heroicgameslauncher.hgl
flatpak install -y flathub net.davidotek.pupgui2
flatpak install -y flathub app.drey.Damask
flatpak install -y flathub org.gnome.FileRoller
flatpak install -y flathub com.github.tchx84.Flatseal
flatpak install flathub org.pipewire.Helvum


# Create necessary directories and templates
mkdir -p ~/.themes ~/.icons ~/.local/share/themes ~/.local/share/icons ~/Templates
touch ~/Templates/"Text File.txt"

# Completion message
echo "Installation complete. Please reboot the system or run 'source ~/.bashrc' to apply the settings."

# Completion
echo "The system will reboot in 1 minute to apply the settings..."
echo "Press Ctrl+C to cancel."
sleep 60
sudo shutdown -r now
