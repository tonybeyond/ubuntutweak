#!/bin/bash

# A basic script to install prefered packages and software to mint cinnamon... should work with other ubuntu based distros with flatpak enabled
#
#

# Exit on error, treat unset variables as an error.
set -eu

# Define variables
DOWNLOADS_PATH="$HOME/Downloads"
GIT_REPO="$DOWNLOADS_PATH/debiantweaks"
LOG_FILE="$DOWNLOADS_PATH/install.log"
URL1="https://assets.msty.app/Msty_amd64.deb"

# Function to log errors
log_error () {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
}

# Function to check if a package is installed
is_package_installed () {
    dpkg -s "$1" &> /dev/null
}

# Function to uninstall unwanted packages with APT
remove_unwanted_packages () {
    echo "Removing some GNOME junk..."
    local packages=("gnome-games" "evolution" "cheese" "gnome-maps" "gnome-music" "gnome-sound-recorder" "rhythmbox" "gnome-weather" "gnome-clocks" "gnome-contacts" "gnome-characters" "videos")
    local thunderbird_packages=($(apt list --installed | grep thunderbird | awk -F/ '{print $1}'))
    local libreoffice_packages=($(apt list --installed | grep libreoffice | awk -F/ '{print $1}'))

    for package in "${packages[@]}"; do
        if is_package_installed "$package"; then
            echo "Removing $package..."
            sudo apt remove -y "$package" || log_error "Failed to remove $package"
        fi
    done

    if [[ ${#thunderbird_packages[@]} -gt 0 ]]; then
        echo "Removing Thunderbird..."
        sudo apt remove -y "${thunderbird_packages[@]}" || log_error "Failed to remove Thunderbird"
    fi

    if [[ ${#libreoffice_packages[@]} -gt 0 ]]; then
        echo "Removing LibreOffice..."
        sudo apt remove -y "${libreoffice_packages[@]}" || log_error "Failed to remove LibreOffice"
    fi

    echo "Cleaning up..."
    sudo apt autoremove --purge -y
    sudo apt autoclean

    echo "Unwanted packages have been removed."
}

# Function to install packages with APT
install_packages () {
    sudo apt update
    sudo apt install -y "$@"
}

# Define package lists
required_packages=(
    "flatpak" "git" "zsh" "btop" "neofetch" "flameshot" "xclip"
    "gimagereader" "tesseract-ocr" "tesseract-ocr-fra" "tesseract-ocr-eng"
    "gnome-shell-extension-appindicator" "gnome-shell-extension-manager"
    "curl" "wget" "build-essential" "node-typescript" "bat" "exa"
    "nala" "vlc" "nextcloud-desktop" "ninja-build" "gettext" "cmake"
    "unzip" "fzf" "remmina" "fd-find" "pipx" "ffmpeg"
)

# Function to install required packages
install_required_packages() {
    echo "Installing required packages..."
    local failed_packages=()
    for package in "${required_packages[@]}"; do
        echo "Checking if $package is installed..."
        if ! is_package_installed "$package"; then
            echo "Installing $package..."
            sudo apt install -y "$package" || failed_packages+=("$package")
        fi
    done

    if [ ${#failed_packages[@]} -gt 0 ]; then
        log_error "Failed to install the following packages: ${failed_packages[*]}"
    fi
}

# Function to install Nerd Fonts
install_nerd_fonts () {
    echo "Installing Nerd Fonts..."
    cd "$DOWNLOADS_PATH" || log_error "Failed to change directory to $DOWNLOADS_PATH"

    if [ ! -d "nerd-fonts" ]; then
        git clone https://github.com/ryanoasis/nerd-fonts.git --depth=1 || log_error "Failed to clone Nerd Fonts repository"
    fi

    cd nerd-fonts || log_error "Failed to change directory to nerd-fonts"
    ./install.sh || log_error "Failed to install Nerd Fonts"
}

# Function to install Brave browser
install_brave_browser () {
    echo "Installing Brave browser..."
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update
    sudo apt install -y brave-browser || log_error "Failed to install Brave browser"
}

# Function to install virtualization packages
install_virtualization () {
    echo "Installing virtualization stack with QEMU/KVM..."
    install_packages qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virtinst libvirt-daemon virt-manager || log_error "Failed to install virtualization packages"
    echo "Enabling and starting libvirtd service..."
    sudo virsh net-start default
    sudo virsh net-autostart default
    sudo systemctl enable libvirtd.service
    echo "<<< ----- Adding user to libvirt and libvirt-qemu groups ----- >>>"
    local groups=("libvirt" "libvirt-qemu")
    for group in ${groups[@]}; do
        sudo adduser $USER $group
    done
}

# Function to install Neovim from repo
install_neovim () {
    echo "Compiling Neovim ..."
    cd "$DOWNLOADS_PATH" || log_error "Failed to change directory to $DOWNLOADS_PATH"

    if [ ! -d "neovim" ]; then
        git clone https://github.com/neovim/neovim --branch=stable --depth=1  || log_error "Failed to clone Neovim repository"
    fi

    cd neovim || log_error "Failed to change directory to neovim"
    make CMAKE_BUILD_TYPE=RelWithDebInfo || log_error "Failed to run make in neovim folder"
    cd build && cpack -G DEB && sudo dpkg -i nvim-linux64.deb || log_error "Failed to run make install in neovim folder"
    echo "Installing Default kickstart config..."
    local kickstart_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    if [ ! -d "$kickstart_config_dir" ]; then
        git clone https://github.com/nvim-lua/kickstart.nvim.git "$kickstart_config_dir" || log_error "Failed clone kickstart neovim config"
    fi
}

# Function to modify locales
modify_locales () {
    echo "Modifying locales..."
    sudo sed -i 's/# fr_CH.UTF/fr_CH.UTF/' /etc/locale.gen
    sudo locale-gen "fr_CH.UTF-8" || log_error "Failed to modify locales"
}

# Function to add Dracula theme to GNOME Terminal
add_dracula_theme () {
    cd "$DOWNLOADS_PATH"
    echo "Adding Dracula theme to GNOME Terminal..."
    if [ ! -d "gnome-terminal" ]; then
        git clone https://github.com/dracula/gnome-terminal || log_error "Failed to clone Dracula GNOME Terminal repository"
    fi
    cd gnome-terminal || log_error "Failed to change directory to gnome-terminal"
    ./install.sh || log_error "Failed to install Dracula GNOME Terminal theme"
}

# Function to download and execute a script
download_and_execute () {
    local url=$1
    local error_message=$2
    curl -fsSL $url | bash || log_error "$error_message"
}

# Function to install Netbird
install_netbird () {
    echo "Installing Netbird..."
    download_and_execute "https://pkgs.netbird.io/install.sh" "Failed to install Netbird"
}

# Function to install Flatpak packages
install_flatpak_packages() {
    echo "Installing Flatpak packages..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    FLATPAK_PACKAGES=("com.parsecgaming.parsec" "md.obsidian.Obsidian" "com.visualstudio.code" "org.nickvision.tubeconverter" "com.github.tchx84.Flatseal" "com.github.flxzt.rnote" "io.github.ungoogled_software.ungoogled_chromium")
    
    for package in "${FLATPAK_PACKAGES[@]}"; do
        echo "Installing $package..."
        flatpak install -y flathub "$package" || log_error "Failed to install $package"
    done
}

# Function to install ZSH and Oh My Zsh
install_zsh_ohmyzsh() {
    if ! is_package_installed zsh; then
        echo "Installing ZSH..."
        sudo apt install -y zsh || log_error "Failed to install zsh"
    fi

    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || log_error "Failed to install Oh My Zsh"

    # Set default shell to ZSH
    chsh -s $(which zsh)
}

# Function to configure Oh My Zsh
configure_ohmyzsh() {
    echo "Getting my zshrc from github..."
    ZSHRC="$HOME/.zshrc"
    curl -fsSL https://raw.githubusercontent.com/tonybeyond/ubuntutweak/main/newzshrc -o "$ZSHRC" || log_error "Failed to download .zshrc"
}

# Function to install miniconda
install_miniconda() {
    echo "installing miniconda"
    cd "$DOWNLOADS_PATH" || log_error "Failed to change directory to $DOWNLOADS_PATH"
    curl -fsSL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" -o Miniconda3-latest-Linux-x86_64.sh  || log_error "Failed to download Miniconda"
    bash Miniconda3-latest-Linux-x86_64.sh || log_error "Failed to install Miniconda"
}

install_ollama() {
    echo "Installing Ollama..."
    download_and_execute "curl -fsSL https://ollama.com/install.sh | sh" "Failed to install ollama"
}


# Function to install downloaded .deb packages
install_debs () {
    local deb_urls=("$URL1")
    local deb_names=("Msty_amd64.deb")

    for i in ${!deb_urls[@]}; do
        if [ ! "${deb_urls[$i]}" =~ ^https?:// ]; then
            log_error "Invalid URL format. Please provide a valid URL."
            return 1
        fi

        wget "${deb_urls[$i]}" -O "${deb_names[i]}" || log_error "Failed to download ${deb_names[i]} package"
        sudo dpkg -i "${deb_names[i]}" || log_error "Failed to install ${deb_names[i]} debian package"
    done
}

# Main installation function
# Function: main_installation
# Description: This function performs the main installation process.
#              It executes the necessary steps to optimize Debian system.
main_installation() {
    # Check if git is installed
    if ! command -v git &> /dev/null
    then
        sudo apt install git -y
    fi

    echo "Starting installation..."

    # Install required packages
    remove_unwanted_packages
    install_required_packages
    install_nerd_fonts

    # Configure system
    modify_locales
    add_dracula_theme

    # Install applications
    install_brave_browser
    install_neovim
    install_netbird
    install_flatpak_packages
    install_ollama

    # Virtualization and miniconda
    install_virtualization
    install_miniconda
    install_debs
    install_zsh_ohmyzsh
    configure_ohmyzsh
   

    echo "Installation completed successfully."
}

#### Check if the script has sudo privileges
if ! sudo -n true 2>/dev/null; then
    # Prompt for sudo password if the script does not have sudo privileges
    echo "This script requires sudo privileges to run. Please enter your password:"
    sudo -v
fi

# Main script
main_installation

# Rebooting
echo "Rebooting system..."
#sudo reboot
