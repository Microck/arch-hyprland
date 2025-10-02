#!/usr/bin/env bash
set -euo pipefail

# Configurable Defaults
WP_DAEMON=""               # auto-detect unless set via --daemon
WALLPAPER=""               # choose from repo wallpapers if empty
COPY_CONFIGS=1
REPO_DIR="$(pwd)"
REPO_CONFIG_DIR="${REPO_DIR}/.config"
REPO_WALL_DIR="${REPO_DIR}/wallpapers"
WALL_DIR="${HOME}/Pictures/Wallpapers"

usage() {
  cat <<EOF
Usage: $0 [--daemon swww|hyprpaper] [--wallpaper PATH] [--no-copy]

Examples:
  $0
  $0 --wallpaper ~/Pictures/Wallpapers/red.jpg
  $0 --daemon hyprpaper
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --daemon) WP_DAEMON="${2:-}"; shift 2 ;;
    --wallpaper) WALLPAPER="${2:-}"; shift 2 ;;
    --no-copy) COPY_CONFIGS=0; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

say() { printf "\n==> %s\n" "$*"; }
warn() { printf "[warn] %s\n" "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1; }

ensure_yay() {
  if need yay; then return; fi
  say "Installing yay..."
  sudo pacman -S --needed --noconfirm git base-devel
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

install_packages() {
  say "Installing packages..."
  yay -S --needed --noconfirm \
    hyprland hyprlock hypridle \
    waybar swaync \
    kitty \
    rofi-lbonn-wayland-git \
    cava fastfetch wlogout \
    matugen-git \
    swww hyprpaper
}

detect_daemon() {
  local chosen=""
  local repo_conf="${REPO_CONFIG_DIR}/hypr/hyprland.conf"
  local user_conf="${HOME}/.config/hypr/hyprland.conf"

  if [[ -f "$repo_conf" ]]; then
    grep -qi 'swww' "$repo_conf" && chosen="swww"
    grep -qi 'hyprpaper' "$repo_conf" && chosen="hyprpaper"
  fi
  if [[ -z "$chosen" && -f "$user_conf" ]]; then
    grep -qi 'swww' "$user_conf" && chosen="swww"
    grep -qi 'hyprpaper' "$user_conf" && chosen="hyprpaper"
  fi
  [[ -z "$chosen" ]] && chosen="swww"
  echo "$chosen"
}

backup_and_copy_configs() {
  [[ "$COPY_CONFIGS" -eq 1 ]] || { say "Skipping config copy."; return; }
  if [[ ! -d "$REPO_CONFIG_DIR" ]]; then
    warn "Repo .config not found: $REPO_CONFIG_DIR"
    return
  fi
  local ts bak
  ts="$(date +%Y%m%d-%H%M%S)"
  bak="${HOME}/.config-backup-${ts}"
  say "Backing up ~/.config -> $bak"
  mkdir -p "$bak"

  mapfile -t items < <(find "$REPO_CONFIG_DIR" -maxdepth 1 -mindepth 1 -type d -printf "%f\n")
  for name in "${items[@]}"; do
    local src dst
    src="${REPO_CONFIG_DIR}/${name}"
    dst="${HOME}/.config/${name}"
    [[ -e "$dst" ]] && mv "$dst" "${bak}/${name}"
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    say "Installed config: ${name}"
  done
}

pick_wallpaper() {
  mkdir -p "$WALL_DIR"
  if [[ -z "$WALLPAPER" ]]; then
    if [[ -d "$REPO_WALL_DIR" ]]; then
      mapfile -t imgs < <(find "$REPO_WALL_DIR" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
      [[ ${#imgs[@]} -gt 0 ]] && WALLPAPER="${imgs[0]}"
    fi
  fi
  if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
    local base
    base="$(basename "$WALLPAPER")"
    cp -f "$WALLPAPER" "${WALL_DIR}/${base}"
    WALLPAPER="${WALL_DIR}/${base}"
  else
    warn "No wallpaper found; you can rerun with --wallpaper PATH."
    WALLPAPER=""
  fi
}

apply_wallpaper_swww() {
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    warn "Wayland not active; skipping swww init."
    return
  fi
  swww init || true
  [[ -n "$WALLPAPER" ]] && \
    swww img "$WALLPAPER" --transition-type grow --transition-duration 0.7 || true
}

apply_wallpaper_hyprpaper() {
  local cfg="${HOME}/.config/hypr/hyprpaper.conf"
  mkdir -p "$(dirname "$cfg")"
  : >"$cfg"
  [[ -n "$WALLPAPER" ]] && {
    echo "preload = ${WALLPAPER}" >>"$cfg"
    echo "wallpaper = ,${WALLPAPER}" >>"$cfg"
  }
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    pkill hyprpaper 2>/dev/null || true
    nohup hyprpaper >/dev/null 2>&1 &
  fi
}

run_matugen() {
  if ! need matugen; then
    warn "matugen not found; skipping theme generation."
    return
  fi
  if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
    say "Generating theme with Matugen from: $WALLPAPER"
    matugen image "$WALLPAPER" || warn "Matugen exited with non-zero status."
  else
    warn "No wallpaper supplied to Matugen."
  fi
}

restart_panels() {
  say "Restarting Waybar and SwayNC..."
  pkill waybar 2>/dev/null || true
  pkill swaync 2>/dev/null || true
  nohup waybar >/dev/null 2>&1 &
  nohup swaync >/dev/null 2>&1 &
}

post_notes() {
  cat <<'TXT'

Notes:
- Waybar’s style/colors.css is Matugen-generated, so colors match your
  wallpaper automatically after each run of `matugen image`.
- Ensure Hyprland autostarts services in `~/.config/hypr/hyprland.conf`:
    exec-once = waybar &
    exec-once = swaync &
    # pick one:
    # exec-once = swww init &
    # exec-once = hyprpaper &
- To change wallpaper later:
    swww img ~/Pictures/Wallpapers/FILE.jpg && matugen image ~/Pictures/Wallpapers/FILE.jpg
  OR if using hyprpaper:
    sed -i "s|^wallpaper = ,.*|wallpaper = ,/path/to/FILE.jpg|" ~/.config/hypr/hyprpaper.conf
    pkill hyprpaper; hyprpaper & disown
    matugen image /path/to/FILE.jpg
TXT
}

main() {
  say "Hyprland rice setup (Matugen-based)"
  ensure_yay
  install_packages
  backup_and_copy_configs
  pick_wallpaper

  if [[ -z "$WP_DAEMON" ]]; then
    WP_DAEMON="$(detect_daemon)"
    say "Wallpaper daemon (auto): ${WP_DAEMON}"
  else
    say "Wallpaper daemon (manual): ${WP_DAEMON}"
  fi

  case "$WP_DAEMON" in
    swww) apply_wallpaper_swww ;;
    hyprpaper) apply_wallpaper_hyprpaper ;;
    *) warn "Unknown daemon: $WP_DAEMON" ;;
  esac

  run_matugen
  restart_panels
  post_notes
  say "Done."
}

main "$@"
