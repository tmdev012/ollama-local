#!/usr/bin/env bash
# install-udev.sh — Install Android udev rules (requires sudo)
# Run: sudo bash ~/ollama-local/scripts/install-udev.sh

RULES="/etc/udev/rules.d/51-android.rules"

printf '%s\n' \
  '# Android ADB udev rules' \
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
  > "$RULES"

chmod 644 "$RULES"
udevadm control --reload-rules
udevadm trigger
usermod -aG plugdev "$SUDO_USER"

echo "✓ udev rules installed → $RULES"
echo "✓ $SUDO_USER added to plugdev group"
echo "  Plug in your phone and run: adb devices"
