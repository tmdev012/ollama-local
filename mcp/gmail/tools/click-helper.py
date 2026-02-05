#!/usr/bin/env python3
"""Use PyAutoGUI to help click through OAuth form"""

import pyautogui
import time
import subprocess
import os

# Safety settings
pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.5

def take_screenshot():
    """Take screenshot to see current state"""
    screenshot = pyautogui.screenshot()
    path = "/tmp/screen.png"
    screenshot.save(path)
    print(f"Screenshot saved: {path}")
    return path

def find_and_click(image_name, confidence=0.8):
    """Find image on screen and click it"""
    try:
        location = pyautogui.locateOnScreen(image_name, confidence=confidence)
        if location:
            pyautogui.click(pyautogui.center(location))
            return True
    except:
        pass
    return False

def main():
    print("OAuth Click Helper")
    print("=" * 40)

    # Take screenshot first
    print("\n[1] Taking screenshot to analyze...")
    screenshot_path = take_screenshot()

    print("\n[2] Looking for form elements...")

    # Try to find common UI elements by text/patterns
    # This is limited without image templates, but we can try

    # Get screen size
    screen_width, screen_height = pyautogui.size()
    print(f"Screen size: {screen_width}x{screen_height}")

    # Try clicking in the middle-ish area where dropdown usually is
    # Google Cloud Console typically has form in center

    print("\n[3] Attempting to interact with form...")
    print("    If this doesn't work, please complete manually")

    # Move to approximate dropdown location (center-left of screen)
    center_x = screen_width // 2
    form_y = screen_height // 2 - 100

    print(f"    Moving to approximate form area: ({center_x}, {form_y})")
    pyautogui.moveTo(center_x - 200, form_y)
    time.sleep(1)

    # Take another screenshot
    take_screenshot()

    print("\nScreenshot saved to /tmp/screen.png")
    print("Please check Firefox window and complete the 3 clicks manually.")

if __name__ == "__main__":
    main()
