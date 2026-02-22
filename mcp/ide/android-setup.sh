#!/usr/bin/env bash
# android-setup.sh — Bootstrap Android SDK (cmdline-tools + platform-tools + build-tools)
set -e

source ~/ollama-local/.env

SDK_DIR="$HOME/Android/Sdk"
TOOLS_DIR="$SDK_DIR/cmdline-tools"
TOOLS_ZIP="$HOME/android-cmdline-tools.zip"

# ── Download cmdline-tools if needed ──────────────────────────────────────────
if [ ! -f "$TOOLS_DIR/latest/bin/sdkmanager" ]; then
    echo "▶ Downloading Android cmdline-tools..."
    TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    wget -q --show-progress -O "$TOOLS_ZIP" "$TOOLS_URL"
    mkdir -p "$TOOLS_DIR/latest"
    unzip -q "$TOOLS_ZIP" -d "$TOOLS_DIR/_tmp"
    mv "$TOOLS_DIR/_tmp/cmdline-tools/"* "$TOOLS_DIR/latest/"
    rm -rf "$TOOLS_DIR/_tmp" "$TOOLS_ZIP"
    echo "✓ cmdline-tools installed"
else
    echo "✓ cmdline-tools already present"
fi

export PATH="$TOOLS_DIR/latest/bin:$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"

SDKMANAGER="$TOOLS_DIR/latest/bin/sdkmanager"

# ── Accept licenses ───────────────────────────────────────────────────────────
echo "▶ Accepting SDK licenses..."
yes | "$SDKMANAGER" --licenses > /dev/null 2>&1 || true

# ── Install required components ───────────────────────────────────────────────
echo "▶ Installing platform-tools (adb)..."
"$SDKMANAGER" "platform-tools"

echo "▶ Installing build-tools 34.0.0..."
"$SDKMANAGER" "build-tools;34.0.0"

echo "▶ Installing android-34 platform..."
"$SDKMANAGER" "platforms;android-34"

# ── Verify adb ────────────────────────────────────────────────────────────────
ADB="$SDK_DIR/platform-tools/adb"
if [ -f "$ADB" ]; then
    echo ""
    echo "✓ adb installed: $($ADB version | head -1)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  NOW: Connect your Android phone via USB"
    echo "  ON PHONE:"
    echo "    Settings → About phone → tap Build number 7×"
    echo "    Settings → Developer options → USB debugging → ON"
    echo "    Plug in USB cable → allow this computer"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "▶ Waiting for device (Ctrl+C to skip)..."
    "$ADB" wait-for-device
    echo ""
    echo "✓ Device connected:"
    "$ADB" devices -l
    echo ""
    echo "Run: sashi ide"
else
    echo "✗ adb not found after install — check errors above"
    exit 1
fi
