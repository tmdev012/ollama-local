#!/usr/bin/env bash
# android-setup.sh — Install Android platform-tools (adb, fastboot) on Linux x86_64
# Part of SASHI v3.2.0 ecosystem
# Usage: bash ~/ollama-local/scripts/android-setup.sh

set -euo pipefail

PLATFORM_TOOLS_URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
INSTALL_DIR="$HOME/Android/platform-tools"
PROFILE_FILE="$HOME/.zshrc"
TEMP_ZIP="/tmp/platform-tools-linux.zip"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
info() { echo -e "  ${BLUE}→${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; exit 1; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Android Platform-Tools Installer    ║${NC}"
echo -e "${BLUE}║  adb + fastboot — SASHI v3.2.0       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""

# ── 1. Check dependencies ────────────────────────────────────────────────────
info "Checking dependencies..."
for dep in curl unzip; do
    if ! command -v "$dep" &>/dev/null; then
        warn "$dep not found — installing..."
        sudo apt-get install -y "$dep" -qq || fail "Cannot install $dep"
    fi
done
ok "Dependencies satisfied"

# ── 2. Check if already installed ────────────────────────────────────────────
if command -v adb &>/dev/null; then
    EXISTING=$(adb version | head -1)
    warn "adb already installed: $EXISTING"
    read -rp "  Reinstall? [y/N] " ans
    [[ "${ans,,}" != "y" ]] && echo "" && ok "Keeping existing install." && exit 0
fi

# ── 3. Download platform-tools ───────────────────────────────────────────────
info "Downloading platform-tools from Google..."
info "URL: $PLATFORM_TOOLS_URL"
curl -L --progress-bar "$PLATFORM_TOOLS_URL" -o "$TEMP_ZIP" \
    || fail "Download failed — check internet connection"
ok "Downloaded to $TEMP_ZIP"

# ── 4. Extract ───────────────────────────────────────────────────────────────
info "Extracting to $HOME/Android/..."
mkdir -p "$HOME/Android"
unzip -q -o "$TEMP_ZIP" -d "$HOME/Android/"
rm -f "$TEMP_ZIP"
ok "Extracted → $INSTALL_DIR"

# ── 5. Verify binaries ───────────────────────────────────────────────────────
for bin in adb fastboot; do
    [[ -f "$INSTALL_DIR/$bin" ]] || fail "$bin not found after extract"
    chmod +x "$INSTALL_DIR/$bin"
done
ok "Binaries verified (adb, fastboot)"

# ── 6. Add to PATH ───────────────────────────────────────────────────────────
PATH_LINE="export PATH=\"\$PATH:$INSTALL_DIR\""

add_to_profile() {
    local pfile="$1"
    if [[ -f "$pfile" ]]; then
        if grep -q "platform-tools" "$pfile" 2>/dev/null; then
            warn "PATH already set in $pfile — skipping"
        else
            echo "" >> "$pfile"
            echo "# Android platform-tools (adb, fastboot)" >> "$pfile"
            echo "$PATH_LINE" >> "$pfile"
            ok "Added to $pfile"
        fi
    fi
}

add_to_profile "$HOME/.zshrc"
add_to_profile "$HOME/.bashrc"

# Apply to current session
export PATH="$PATH:$INSTALL_DIR"

# ── 7. udev rules (allow non-root adb) ───────────────────────────────────────
UDEV_RULES="/etc/udev/rules.d/51-android.rules"
if [[ ! -f "$UDEV_RULES" ]]; then
    info "Installing udev rules for USB access (needs sudo)..."
    printf '%s\n' \
        '# Android ADB — allow current user without root' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="2717", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="1ebf", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="0fce", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", MODE="0666", GROUP="plugdev"' \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="2a70", MODE="0666", GROUP="plugdev"' \
        | sudo tee "$UDEV_RULES" > /dev/null
    sudo chmod 644 "$UDEV_RULES"
    sudo udevadm control --reload-rules 2>/dev/null && sudo udevadm trigger 2>/dev/null || true
    ok "udev rules installed → $UDEV_RULES"
else
    ok "udev rules already present"
fi

# Ensure user is in plugdev group
if ! groups | grep -q plugdev; then
    info "Adding $USER to plugdev group..."
    sudo usermod -aG plugdev "$USER"
    warn "Group change needs logout/login to take full effect (usually fine for USB)"
else
    ok "User already in plugdev group"
fi

# ── 8. Start adb daemon ───────────────────────────────────────────────────────
info "Starting adb daemon..."
"$INSTALL_DIR/adb" start-server 2>/dev/null && ok "adb daemon started" || warn "daemon start deferred (normal without device)"

# ── 9. Version check ──────────────────────────────────────────────────────────
echo ""
ADB_VER=$("$INSTALL_DIR/adb" version | head -1)
FASTBOOT_VER=$("$INSTALL_DIR/fastboot" --version 2>/dev/null | head -1 || echo "fastboot ok")
ok "$ADB_VER"
ok "$FASTBOOT_VER"

# ── 10. Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""
echo "  Install dir : $INSTALL_DIR"
echo "  adb         : $(which adb 2>/dev/null || echo "$INSTALL_DIR/adb")"
echo "  udev rules  : $UDEV_RULES"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. On your phone: Settings → Developer Options → USB Debugging ON"
echo "  2. Plug phone in via USB"
echo "  3. Run: sashi adb status"
echo "     or:  adb devices"
echo ""
echo "  For wireless (after USB first): sashi adb wireless"
echo ""
