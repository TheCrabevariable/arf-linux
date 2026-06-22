#!/usr/bin/env bash
set -euo pipefail

# ── arf-linux ──────────────────────────────────────────────────
# Opinionated Arch Linux installer — like Omarchy, but mine
# Usage: bash install.sh
# ────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { printf "${CYAN}::${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}==>${NC} %s\n" "$*"; }
err()   { printf "${RED}==>${NC} %s\n" "$*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────
# If running inside the ISO-automated flow, these come from /etc/arf-linux.env.
# If running manually, they default to the current user.
USERNAME="${USERNAME:-$USER}"

# ── Stage 1: Live ISO ──────────────────────────────────────────
stage1() {
  clear
  echo "============================================"
  echo "  arf-linux Stage 1 — archinstall"
  echo "============================================"
  echo ""
  echo "You'll now be guided through archinstall's"
  echo "interactive setup. Recommended options:"
  echo ""
  echo "  • Disk config:  your choice (ext4/btrfs,"
  echo "                  encryption optional)"
  echo "  • Filesystem:   ext4 or btrfs"
  echo "  • Bootloader:   grub"
  echo "  • Audio:        pipewire"
  echo "  • Network:      Copy ISO network config"
  echo "  • User:         create your user with sudo"
  echo ""
  echo "After archinstall finishes and you reboot,"
  echo "run:  bash arf-linux/install.sh --stage2"
  echo "============================================"
  echo ""

  # Ensure archinstall is available
  if ! command -v archinstall &>/dev/null; then
    info "Installing archinstall..."
    pacman -Sy --noconfirm archinstall
  fi

  archinstall

  ok "Stage 1 complete. Reboot, then run: bash arf-linux/install.sh --stage2"
}

# ── Stage 2: First boot (pkg install) ──────────────────────────
stage2() {
  info "Stage 2: Installing packages"

  # Tweak pacman.conf
  sed -i 's/^#Color/Color/; s/^#ParallelDownloads = 5/ParallelDownloads = 4/' /etc/pacman.conf
  grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
  grep -q '^VerbosePkgLists' /etc/pacman.conf || sed -i '/^Color/a VerbosePkgLists' /etc/pacman.conf

  # Enable multilib
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo '[multilib]' >> /etc/pacman.conf
    echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
  fi

  pacman -Syu --noconfirm

  # Official packages
  OFFICIAL=(
    hyprland hypridle hyprlock hyprpaper hyprshot hyprpolkitagent hyprpicker
    zed steam kitty fastfetch rmpc mpd networkmanager zsh python
    quickshell ttf-hack-nerd sddm opencode gnome-disk-utility imv mpv pavucontrol yt-dlp
    bluetui bluez bluez-utils playerctl brightnessctl lm_sensors
    pipewire pipewire-pulse wireplumber power-profiles-daemon
    xdg-desktop-portal xdg-desktop-portal-hyprland udiskie
  )

  pacman -S --noconfirm --needed "${OFFICIAL[@]}" os-prober

  # Install yay for AUR
  if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)"
    sudo -u "$USERNAME" bash -c "
      cd /tmp
      git clone https://aur.archlinux.org/yay-bin.git
      cd yay-bin && makepkg -si --noconfirm
    "
  fi

  # AUR packages
  AUR=(
    helium-browser-bin
    animu-bin
    fren-git
  )

  sudo -u "$USERNAME" yay -S --noconfirm --needed "${AUR[@]}"

  # Enable services
  systemctl enable sddm
  systemctl enable bluetooth
  systemctl enable power-profiles-daemon
  sudo -u "$USERNAME" bash -c "
    mkdir -p ~/.config/systemd/user/default.target.wants
    ln -sf /usr/lib/systemd/user/pipewire.service ~/.config/systemd/user/default.target.wants/
    ln -sf /usr/lib/systemd/user/pipewire-pulse.service ~/.config/systemd/user/default.target.wants/
    ln -sf /usr/lib/systemd/user/wireplumber.service ~/.config/systemd/user/default.target.wants/
  "

  # Flatpak
  if ! command -v flatpak &>/dev/null; then
    info "Installing flatpak..."
    pacman -S --noconfirm flatpak flatpak-xdg-utils
  fi
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  sudo -u "$USERNAME" flatpak install -y flathub com.heroicgameslauncher.hgl

  # ── Dotfiles ──────────────────────────────────────────────────
  info "Applying dotfiles..."

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DOTFILES="$SCRIPT_DIR/dotfiles"

  for dir in "$DOTFILES"/*/; do
    app="$(basename "$dir")"
    target="$HOME/.config/$app"
    mkdir -p "$target"
    cp -r "$dir"/* "$target"/ 2>/dev/null || true
    ok "Applied config for $app"
  done

  if [ -f "$DOTFILES/zsh/.zshrc" ]; then
    cp "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
    chsh -s "$(which zsh)" "$USERNAME"
    ok "Applied config for zsh and set as default shell"
  fi

  mkdir -p "$HOME/.config/mpd/playlists"
  touch "$HOME/.config/mpd/database"

  # ── Quickshell config ──────────────────────────────────────────
  info "Setting up Quickshell..."
  if [ -d "$HOME/.config/quickshell" ]; then
    mv "$HOME/.config/quickshell" "$HOME/.config/quickshell.bak"
  fi
  git clone --depth 1 https://github.com/doannc2212/quickshell-config.git "$HOME/.config/quickshell"
  sed -i 's/import "wallpaper"/\/\/import "wallpaper"/' "$HOME/.config/quickshell/shell.qml"
  sed -i 's/WallpaperManager {/# WallpaperManager {/' "$HOME/.config/quickshell/shell.qml"

  # Patch Monitor Manager: keyword doesn't work with Lua config parser
  # Replace buildMonitorArg + apply with persistToFile + hyprctl reload
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  QS_PATCH="$SCRIPT_DIR/dotfiles/quickshell-patch"
  if [ -f "$QS_PATCH/MonitorService.qml" ]; then
    cp "$QS_PATCH/MonitorService.qml" "$HOME/.config/quickshell/monitor-manager/MonitorService.qml"
  fi
  if [ -f "$QS_PATCH/MonitorManager.qml" ]; then
    cp "$QS_PATCH/MonitorManager.qml" "$HOME/.config/quickshell/monitor-manager/MonitorManager.qml"
  fi
  if [ -f "$QS_PATCH/SystemInfo.qml" ]; then
    cp "$QS_PATCH/SystemInfo.qml" "$HOME/.config/quickshell/bar/SystemInfo.qml"
  fi
  if [ -f "$QS_PATCH/Bar.qml" ]; then
    cp "$QS_PATCH/Bar.qml" "$HOME/.config/quickshell/bar/Bar.qml"
  fi
  ok "Quickshell config applied"

  # ── Wallpapers from GitHub ──────────────────────────────────────
  info "Downloading wallpapers..."
  WALLPAPER_DIR="$HOME/.config/hypr/wallpaper"
  mkdir -p "$WALLPAPER_DIR"
  if [ ! -d "$WALLPAPER_DIR/.git" ]; then
    git clone --depth 1 https://github.com/TheCrabevariable/Wallpaper.git "$WALLPAPER_DIR-tmp" 2>/dev/null || true
    if [ -d "$WALLPAPER_DIR-tmp" ]; then
      sudo mkdir -p /usr/share/sddm/themes/arf
      sudo cp "$WALLPAPER_DIR-tmp/sddm/Sddm.jpg" /usr/share/sddm/themes/arf/background.jpg 2>/dev/null || true
      cp "$WALLPAPER_DIR-tmp/hyprlock/hyprlock2.png" "$WALLPAPER_DIR/hyprlock2.png" 2>/dev/null || true
      cp "$WALLPAPER_DIR-tmp/Kosmos/fren1.png" "$WALLPAPER_DIR/fren1.png" 2>/dev/null || true
      rm -rf "$WALLPAPER_DIR-tmp"
      ok "Wallpapers downloaded"
    else
      info "Wallpaper repo not accessible — skipping"
    fi
  fi

  # ── SDDM theme ──────────────────────────────────────────────────
  if [ ! -d /usr/share/sddm/themes/sddm-flower-theme ]; then
    sudo git clone --depth 1 https://github.com/keyitdev/sddm-flower-theme.git /usr/share/sddm/themes/sddm-flower-theme 2>/dev/null || true
  fi
  sudo cp /usr/share/sddm/themes/arf/background.jpg /usr/share/sddm/themes/sddm-flower-theme/background.jpg 2>/dev/null || true
  sudo mkdir -p /etc/sddm.conf.d
  sudo tee /etc/sddm.conf.d/arf.conf > /dev/null << 'SDDM'
[Theme]
Current=sddm-flower-theme
[Users]
MaximumUid=60000
SDDM
  ok "SDDM configured"

  # ── GRUB config ──────────────────────────────────────────────────
  info "Configuring GRUB..."
  cp "$SCRIPT_DIR/dotfiles/grub/fgrub.png" /boot/grub/
  cp "$SCRIPT_DIR/dotfiles/grub/theme.txt" /boot/grub/
  sed -i 's|^#\?GRUB_BACKGROUND=.*|GRUB_BACKGROUND=/boot/grub/fgrub.png|' /etc/default/grub
  sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME=/boot/grub/theme.txt|' /etc/default/grub
  grep -q '^GRUB_GFXMODE=' /etc/default/grub || echo 'GRUB_GFXMODE=1920x1080,auto' >> /etc/default/grub
  sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=".*"|GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"|' /etc/default/grub
  sed -i 's|^#GRUB_DISABLE_OS_PROBER=false|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub || true
  grub-mkconfig -o /boot/grub/grub.cfg
  ok "GRUB configured"

  ok "Stage 2 complete!"

  # If running via the ISO automated flow, reboot automatically
  if [ -f /etc/arf-linux.env ]; then
    info "Rebooting in 5 seconds..."
    sleep 5
    systemctl reboot
  else
    echo "  Reboot to start SDDM and enjoy arf-linux!"
  fi
}

# ── Main ───────────────────────────────────────────────────────
main() {
  case "${1:-}" in
    --stage2) stage2 ;;
    *)        stage1 ;;
  esac
}

main "$@"
