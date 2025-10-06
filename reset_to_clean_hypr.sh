#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
say() { echo -e "${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

# 1️⃣  BACKUP AND CLEAN CONFIG
say "Backing up current ~/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
if [[ -d "$HOME/.config" ]]; then
  mv "$HOME/.config" "$BACKUP_DIR"
  say "Old config moved to $BACKUP_DIR"
fi
mkdir -p "$HOME/.config"

# 2️⃣  REMOVE EXTRA PACKAGES (keep only minimal)
say "Removing rice-related packages (this may take a bit)..."
sudo pacman -Rns --noconfirm waybar swaync rofi* kitty cava fastfetch \
  wlogout matugen* swww hyprpaper blueman network-manager-applet \
  pavucontrol nautilus yazi spotify vesktop telegram-desktop \
  discord grim slurp hyprpicker brightnessctl polkit-gnome \
  firefox thunderbird || true
say "Skipped any packages that were not installed."

# 3️⃣  INSTALL CLEAN BASE
say "Installing base Hyprland environment..."
sudo pacman -S --needed --noconfirm \
  hyprland hypridle hyprlock xdg-desktop-portal-hyprland pipewire wireplumber kitty

# 4️⃣  CREATE MINIMAL CONFIG
say "Creating minimal Hyprland config..."
mkdir -p "$HOME/.config/hypr"
cat > "$HOME/.config/hypr/hyprland.conf" << 'EOF'
monitor=,preferred,auto,1

# Launch terminal on start
exec-once = kitty

# Keybinds
bind = SUPER,Return,exec,kitty
bind = SUPER,Q,killactive
bind = SUPER,M,exit
EOF

say "All done! 🎉"
cat << 'NEXT'

✅ Your system now has a clean Hyprland setup.

Next steps:
1. Log out of your current desktop or TTY.
2. Run   Hyprland
   (capital H) to start the compositor.

You’ll see a blank screen and can open Kitty with Super+Enter.

After you confirm this works:
→ you can slowly reinstall and configure Waybar, Rofi, Swww, etc.

NEXT
