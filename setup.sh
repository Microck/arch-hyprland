#!/usr/bin/env bash
set -e

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
say() { echo -e "${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
ask() {
    local prompt="$1"
    local var="$2"
    echo -e "${BLUE}[?]${NC} $prompt"
    read -r "$var"
}
ask_yn() {
    local prompt="$1"
    local response
    while true; do
        echo -e "${BLUE}[?]${NC} $prompt (y/n): "
        read -r response
        case "$response" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) warn "Please answer y or n." ;;
        esac
    done
}

clear
cat << "EOF"
╔═══════════════════════════════════════════════╗
║                                               ║
║     🚀 Hyprland Rice Installer 🚀            ║
║                                               ║
║     Arch Linux + Hyprland Setup              ║
║     Simple, Interactive, Foolproof           ║
║                                               ║
╚═══════════════════════════════════════════════╝
EOF

say "This script will guide you through setting up your Hyprland rice."
say "Press ENTER to continue..."
read -r

# Check if we're on Arch
if ! command -v pacman >/dev/null; then
    error "This script is for Arch Linux only!"
    exit 1
fi

# Step 1: Install yay if missing
say "Step 1/8: Checking for yay (AUR helper)..."
if ! command -v yay >/dev/null; then
    warn "yay not found. Installing yay..."
    if ask_yn "Install yay (required for AUR packages)?"; then
        sudo pacman -S --needed --noconfirm git base-devel
        tmp="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$tmp/yay"
        (cd "$tmp/yay" && makepkg -si --noconfirm)
        rm -rf "$tmp"
        say "yay installed successfully!"
    else
        error "Cannot continue without yay."
        exit 1
    fi
else
    say "yay found ✓"
fi

# Step 2: Update system
say "\nStep 2/8: System update"
if ask_yn "Update system packages first? (recommended)"; then
    yay -Syu --noconfirm
fi

# Step 3: Install packages
say "\nStep 3/8: Installing packages"
if ask_yn "Install all required packages? (this may take a while)"; then
    say "Installing core packages..."
    yay -S --needed --noconfirm \
        hyprland hypridle hyprlock waybar swaync swww \
        kitty rofi-lbonn-wayland-git wlogout nautilus \
        ttf-jetbrains-mono-nerd ttf-font-awesome ttf-material-design-icons \
        polkit-gnome xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
        grim slurp hyprpicker brightnessctl pavucontrol blueman \
        network-manager-applet fastfetch cava jq curl wget git \
        pipewire pipewire-pulse wireplumber || {
            error "Package installation failed!"
            exit 1
        }
    
    say "Installing AUR packages..."
    yay -S --needed --noconfirm matugen-bin || warn "matugen install failed, continuing..."
    
    say "All packages installed ✓"
else
    warn "Skipping package installation (you may have missing dependencies)"
fi

# Step 4: Backup existing configs
say "\nStep 4/8: Backing up existing configs"
if [[ -d ~/.config/hypr ]] || [[ -d ~/.config/waybar ]]; then
    if ask_yn "Existing configs found. Create backup?"; then
        backup_dir=~/.config-backup-$(date +%Y%m%d-%H%M%S)
        mkdir -p "$backup_dir"
        for dir in hypr waybar rofi kitty swaync matugen cava fastfetch wlogout; do
            [[ -d ~/.config/$dir ]] && mv ~/.config/$dir "$backup_dir/"
        done
        say "Backup created at: $backup_dir"
    fi
fi

# Step 5: Copy config files
say "\nStep 5/8: Installing configuration files"
if ask_yn "Copy configuration files to ~/.config?"; then
    mkdir -p ~/.config
    for dir in .config/*; do
        if [[ -d "$dir" ]]; then
            name=$(basename "$dir")
            cp -r "$dir" ~/.config/
            say "Installed: $name"
        fi
    done
    
    # Make scripts executable
    if [[ -d ~/.config/hypr/scripts ]]; then
        chmod +x ~/.config/hypr/scripts/*.sh
        say "Made scripts executable"
    fi
    
    say "Configs installed ✓"
else
    error "Cannot continue without configs!"
    exit 1
fi

# Step 6: Wallpaper setup
say "\nStep 6/8: Wallpaper setup"
mkdir -p ~/Pictures/Wallpapers

if [[ -d wallpapers ]] && [[ $(ls wallpapers/*.{jpg,png,jpeg,webp} 2>/dev/null | wc -l) -gt 0 ]]; then
    if ask_yn "Copy wallpapers from repo?"; then
        cp wallpapers/* ~/Pictures/Wallpapers/ 2>/dev/null || true
        say "Wallpapers copied to ~/Pictures/Wallpapers/"
    fi
fi

# Let user choose wallpaper
mapfile -t walls < <(find ~/Pictures/Wallpapers -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
if [[ ${#walls[@]} -eq 0 ]]; then
    warn "No wallpapers found in ~/Pictures/Wallpapers/"
    warn "You can add wallpapers later and run: swww img /path/to/image.jpg"
    CHOSEN_WALL=""
else
    say "Found ${#walls[@]} wallpaper(s)."
    say "Choose a wallpaper:"
    for i in "${!walls[@]}"; do
        echo "  $((i+1)). $(basename "${walls[$i]}")"
    done
    ask "Enter number (or press ENTER for first one)" choice
    if [[ -z "$choice" ]]; then
        choice=1
    fi
    idx=$((choice-1))
    if [[ $idx -ge 0 ]] && [[ $idx -lt ${#walls[@]} ]]; then
        CHOSEN_WALL="${walls[$idx]}"
        say "Selected: $(basename "$CHOSEN_WALL")"
    else
        CHOSEN_WALL="${walls[0]}"
        say "Invalid choice, using: $(basename "$CHOSEN_WALL")"
    fi
fi

# Step 7: Generate theme with Matugen
say "\nStep 7/8: Generating color scheme"
if command -v matugen >/dev/null && [[ -n "$CHOSEN_WALL" ]]; then
    if ask_yn "Generate color scheme from wallpaper with Matugen?"; then
        matugen image "$CHOSEN_WALL" || warn "Matugen failed, colors may be default"
        say "Color scheme generated ✓"
    fi
fi

# Step 8: Set up autostart and fix exec-once
say "\nStep 8/8: Finalizing Hyprland config"
HYPR_CONF=~/.config/hypr/hyprland.conf
if [[ -f "$HYPR_CONF" ]]; then
    # Fix swww-daemon → swww init
    if grep -q "swww-daemon" "$HYPR_CONF"; then
        sed -i 's/swww-daemon/swww init/g' "$HYPR_CONF"
        say "Fixed swww-daemon → swww init"
    fi
    
    # Add matugen --watch if missing
    if ! grep -q "matugen" "$HYPR_CONF"; then
        echo "exec-once = matugen --watch" >> "$HYPR_CONF"
        say "Added matugen --watch to autostart"
    fi
fi

# Enable services
say "\nEnabling system services..."
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
systemctl --user enable hypridle 2>/dev/null || true

# Apply wallpaper now if in Wayland session
if [[ -n "${WAYLAND_DISPLAY}" ]] && [[ -n "$CHOSEN_WALL" ]]; then
    if ask_yn "Apply wallpaper now?"; then
        swww init 2>/dev/null || true
        swww img "$CHOSEN_WALL" --transition-type grow --transition-duration 0.7
        say "Wallpaper applied!"
    fi
fi

# Restart Waybar/Swaync if running
if pgrep waybar >/dev/null; then
    if ask_yn "Restart Waybar and SwayNC now?"; then
        pkill waybar swaync 2>/dev/null || true
        waybar & disown
        swaync & disown
        say "Panels restarted!"
    fi
fi

# Final message
clear
cat << "EOF"
╔═══════════════════════════════════════════════╗
║                                               ║
║          ✅ Installation Complete! ✅         ║
║                                               ║
╚═══════════════════════════════════════════════╝

🎉 Your Hyprland rice is ready!

📌 Next Steps:
   1. Log out of your current session
   2. Select "Hyprland" in your display manager
   3. Log in

🔑 Essential Keybindings:
   Super + Enter       → Open terminal (Kitty)
   Super + D           → Application launcher (Rofi)
   Super + Q           → Close window
   Super + W           → Wallpaper picker
   Super + L           → Lock screen
   Super + M           → Exit Hyprland

📁 Important Paths:
   Configs:     ~/.config/hypr/
   Wallpapers:  ~/Pictures/Wallpapers/
   Backup:      ~/.config-backup-*/

🐛 If something looks wrong:
   1. Reload Hyprland: Super + Shift + R
   2. Restart Waybar: Super + R
   3. Change colors: matugen image /path/to/wallpaper.jpg

📖 Full documentation:
   https://github.com/Microck/arch-hyprland

EOF

if ask_yn "Start Hyprland now?"; then
    exec Hyprland
else
    say "Setup complete. Run 'Hyprland' when ready!"
fi
