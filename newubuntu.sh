#!/bin/bash

# Exit on error, treat unset variables as an error.
set -eu

# Define variables
downloads_path="$HOME/Downloads"
git_repo="$downloads_path/ubuntutweak-main"
log_file="$downloads_path/install.log"
url1="https://builds.parsec.app/package/parsec-linux.deb"

# Function to log errors
log_error() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$log_file"
}

# Function to check if a package is installed
is_package_installed() {
  dpkg -s "$1" &> /dev/null
}

# Function to uninstall unwanted packages with APT
remove_unwanted_packages() {
  echo "Removing some GNOME junk..."
  local packages=(
    "gnome-games"
    "evolution"
    "cheese"
    "gnome-maps"
    "gnome-music"
    "gnome-sound-recorder"
    "rhythmbox"
    "gnome-weather"
    "gnome-clocks"
    "gnome-contacts"
    "gnome-characters"
  )
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
install_packages() {
  sudo apt update
  sudo apt install -y "$@"
}

# Function to install Git
install_git() {
  if ! is_package_installed git; then
    echo "Installing git..."
    install_packages git || log_error "Failed to install git"
  fi
}

# Function to install other packages
install_other_packages() {
  local packages=(
    "zsh*"
    "wezterm" 
    "gnome-tweaks"
    "btop"
    "hyfetch"
    "flameshot"
    "xclip"
    "gimagereader"
    "tesseract-ocr"
    "tesseract-ocr-fra"
    "tesseract-ocr-eng"
    "gnome-shell-extension-appindicator"
    "gnome-shell-extension-manager"
    "curl"
    "wget"
    "build-essential"
    "node-typescript"
    "bat"
    "exa"
    "nala"
    "vlc"
    "eza"
  )
  local failed_packages=()

  for package in "${packages[@]}"; do
    echo "Checking if $package is installed..."
    if ! is_package_installed "$package"; then
      echo "Installing $package..."
      install_packages "$package" || failed_packages+=("$package")
    fi
  done

  if [ ${#failed_packages[@]} -gt 0 ]; then
    log_error "Failed to install the following packages: ${failed_packages[*]}"
  fi
}

# Function to install virtualization packages
install_virtualization() {
  echo "Installing virtualization stack with QEMU/KVM..."
  install_packages qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virtinst libvirt-daemon virt-manager || log_error "Failed to install virtualization packages"
  
  echo "Enabling and starting libvirtd service..."
  sudo virsh net-start default
  sudo virsh net-autostart default
  sudo systemctl enable libvirtd.service
  sudo systemctl start libvirtd
  
  echo "<<< ----- Adding user to libvirt and libvirt-qemu groups ----- >>>"
  sudo adduser "$USER" libvirt
  sudo adduser "$USER" libvirt-qemu
}

# Function to install Nerd Fonts
install_nerd_fonts() {
  echo "Installing Nerd Fonts..."
  cd "$downloads_path" || log_error "Failed to change directory to $downloads_path"
  
  if [ ! -d "nerd-fonts" ]; then
    git clone https://github.com/ryanoasis/nerd-fonts.git --depth=1 || log_error "Failed to clone Nerd Fonts repository"
  fi
  
  cd nerd-fonts || log_error "Failed to change directory to nerd-fonts"
  ./install.sh || log_error "Failed to install Nerd Fonts"
}

# Function to install Brave browser
install_brave_browser() {
  echo "Installing Brave browser..."
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  install_packages brave-browser || log_error "Failed to install Brave browser"
}

# Function to install Snap packages
install_snaps() {
  echo "Installing Snap packages..."
  sudo snap install notion-snap-reborn || log_error "Failed to install Notion Snap package"
  sudo snap install vscode --classic || log_error "Failed to install VS Code Snap package"
}

# Function to modify locales
modify_locales() {
  echo "Modifying locales..."
  sudo sed -i 's/# fr_CH.UTF/fr_CH.UTF/' /etc/locale.gen
  sudo locale-gen || log_error "Failed to modify locales"
}

# Function to install Pop Shell
install_pop_shell() {
  cd "$downloads_path" || log_error "Failed to change directory to $downloads_path"
  echo "Installing Pop Shell..."
  
  if [ ! -d "shell" ]; then
    git clone https://github.com/pop-os/shell.git --depth=1 || log_error "Failed to clone Pop Shell repository"
  fi
  
  cd shell || log_error "Failed to change directory to shell"
  make local-install || log_error "Failed to install Pop Shell"
}

# Function to install Neovim from repo
install_neovim() {
  echo "Compiling Neovim..."
  cd "$downloads_path" || log_error "Failed to change directory to $downloads_path"
  
  if [ ! -d "neovim" ]; then
    git clone https://github.com/neovim/neovim --branch=stable --depth=1 || log_error "Failed to clone Neovim repository"
  fi
  
  cd neovim || log_error "Failed to change directory to neovim"
  make CMAKE_BUILD_TYPE=RelWithDebInfo || log_error "Failed to run make in neovim folder"
  cd build && cpack -G DEB && sudo dpkg -i nvim-linux64.deb || log_error "Failed to install Neovim"
  
  echo "Installing Default kickstart config..."
  local kickstart_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
  if [ ! -d "$kickstart_config_dir" ]; then
    git clone https://github.com/nvim-lua/kickstart.nvim.git "$kickstart_config_dir" || log_error "Failed clone kickstart neovim config"
  fi
}

# Function to install wezterm repos
install_wez() {
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
  echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
}

# Function to download and execute a script
download_and_execute() {
  local url=$1
  local error_message=$2
  curl -fsSL "$url" | bash || log_error "$error_message"
}

# Function to install downloaded .deb packages
install_debs() {
  local deb_urls=("$url1")
  local deb_names=("parsec.deb")

  if [ ${#deb_urls[@]} -ne ${#deb_names[@]} ]; then
    log_error "Number of URLs and package names do not match."
    return 1
  fi

  for i in "${!deb_urls[@]}"; do
    if [[ ! "${deb_urls[$i]}" =~ ^https?:// ]]; then
      log_error "Invalid URL format: ${deb_urls[$i]}"
      return 1
    fi
    
    wget "${deb_urls[$i]}" -O "${deb_names[i]}" || log_error "Failed to download ${deb_names[i]} package"
    sudo dpkg -i "${deb_names[i]}" || log_error "Failed to install ${deb_names[i]} package"
  done
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || log_error "Failed to install Oh My Zsh"
}

# Check if the script has sudo privileges
if ! sudo -n true 2>/dev/null; then
  # Prompt for sudo password if the script does not have sudo privileges
  echo "This script requires sudo privileges to run. Please enter your password:"
  sudo -v
fi

# Main script
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
remove_unwanted_packages
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_git
install_wez
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_other_packages
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_nerd_fonts
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_brave_browser
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_snaps
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
modify_locales
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_debs
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_neovim
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_pop_shell
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
install_oh_my_zsh
echo "---------------------*******************************************************************-----------------------------------"
echo "---------------------*******************************************************************-----------------------------------"
echo "Installation has completed. Let's reboot"
echo "Reboot and enjoy"
sudo reboot
