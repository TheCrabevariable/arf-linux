#!/usr/bin/env bash
set -euo pipefail

# ── arf-linux ISO builder ─────────────────────────────────────
# Builds a custom Arch Linux live ISO with automated installer.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="$SCRIPT_DIR/profiledir"
WORK_DIR="/tmp/arf-linux-iso-work"
OUT_DIR="$SCRIPT_DIR/out"

# Ensure archiso is installed
if ! command -v mkarchiso &>/dev/null; then
  echo ":: Installing archiso..."
  sudo pacman -S --noconfirm archiso
fi

# Bundle arf-linux into the airootfs
echo ":: Bundling arf-linux into ISO..."
ARF_DEST="$PROFILE/airootfs/opt/arf-linux"
sudo rm -rf "$ARF_DEST" 2>/dev/null || true
mkdir -p "$ARF_DEST"
cp -r --no-preserve=mode,ownership,xattr "$SCRIPT_DIR/../arf-linux"/* "$ARF_DEST/" 2>/dev/null || {
  echo "!! arf-linux source not found at ../arf-linux"
  echo "   Place the arf-linux directory next to arf-linux-iso/"
  exit 1
}
# Bundle SDDM theme so install doesn't need GitHub
echo ":: Bundling SDDM theme..."
SDDM_DEST="$PROFILE/airootfs/usr/share/sddm/themes"
if git clone --depth 1 https://github.com/keyitdev/sddm-flower-theme.git "$SDDM_DEST/sddm-flower-theme" 2>/dev/null; then
  echo ":: SDDM theme bundled"
else
  echo "!! Warning: could not clone SDDM theme (no internet?)"
  echo "   Install will fall back to built-in theme"
  rm -rf "$SDDM_DEST/sddm-flower-theme" 2>/dev/null || true
fi

# Bundle quickshell config (patched) so install doesn't need GitHub
echo ":: Bundling Quickshell config..."
QS_REPO="https://github.com/doannc2212/quickshell-config.git"
QS_TMP=$(mktemp -d)
if git clone --depth 1 "$QS_REPO" "$QS_TMP/quickshell" 2>/dev/null; then
  sed -i 's/import "wallpaper"/\/\/import "wallpaper"/' "$QS_TMP/quickshell/shell.qml"
  sed -i 's/WallpaperManager {/\/\/WallpaperManager {/' "$QS_TMP/quickshell/shell.qml"
  for f in MonitorService.qml MonitorManager.qml; do
    [ -f "$ARF_DEST/dotfiles/quickshell-patch/$f" ] && \
      cp "$ARF_DEST/dotfiles/quickshell-patch/$f" "$QS_TMP/quickshell/monitor-manager/$f"
  done
  for f in SystemInfo.qml Bar.qml; do
    [ -f "$ARF_DEST/dotfiles/quickshell-patch/$f" ] && \
      cp "$ARF_DEST/dotfiles/quickshell-patch/$f" "$QS_TMP/quickshell/bar/$f"
  done
  sudo rm -rf "$ARF_DEST/dotfiles/quickshell" 2>/dev/null || true
  cp -r "$QS_TMP/quickshell" "$ARF_DEST/dotfiles/quickshell"
  echo ":: Quickshell config bundled"
else
  echo "!! Warning: could not clone quickshell-config (no internet?)"
  echo "   Quickshell bar will fall back to patches only"
fi
rm -rf "$QS_TMP"

# Clean previous build
sudo rm -rf "$WORK_DIR" "$OUT_DIR" 2>/dev/null || true
mkdir -p "$OUT_DIR"

# Build the ISO
echo ":: Building ISO (this may take a while)..."
sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE"

# Fix ownership
sudo chown -R "$(whoami):$(whoami)" "$OUT_DIR" 2>/dev/null || true

echo ""
echo "✅ ISO built: $OUT_DIR/arf-linux-*.iso"
echo "   Write to USB: sudo dd if=$OUT_DIR/arf-linux-*.iso of=/dev/sdX bs=4M status=progress && sync"
