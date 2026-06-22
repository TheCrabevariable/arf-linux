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
mkdir -p "$ARF_DEST"
cp -r --no-preserve=mode,ownership,xattr "$SCRIPT_DIR/../arf-linux"/* "$ARF_DEST/" 2>/dev/null || {
  echo "!! arf-linux source not found at ../arf-linux"
  echo "   Place the arf-linux directory next to arf-linux-iso/"
  exit 1
}
# Clean previous build
rm -rf "$WORK_DIR" "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Build the ISO
echo ":: Building ISO (this may take a while)..."
sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE"

# Fix ownership
sudo chown -R "$(whoami):$(whoami)" "$OUT_DIR" 2>/dev/null || true

echo ""
echo "✅ ISO built: $OUT_DIR/arf-linux-*.iso"
echo "   Write to USB: sudo dd if=$OUT_DIR/arf-linux-*.iso of=/dev/sdX bs=4M status=progress && sync"
