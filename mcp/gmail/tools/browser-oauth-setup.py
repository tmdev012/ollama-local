#!/usr/bin/env python3
"""
Automated Browser OAuth Setup for Gmail API
Uses Selenium to automate the OAuth client creation in Google Cloud Console
"""

import os
import sys
import time
import glob
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

CONFIG_DIR = os.path.expanduser("~/ollama-local/mcp/gmail/config")
DOWNLOADS_DIR = os.path.expanduser("~/Downloads")
PROJECT_ID = "tm012-git-tracking"

def setup_driver():
    """Setup Chrome with proper options"""
    options = Options()
    # Use existing Chrome profile to reuse login session
    options.add_argument(f"--user-data-dir={os.path.expanduser('~/.config/google-chrome')}")
    options.add_argument("--profile-directory=Default")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    # Set download directory
    prefs = {
        "download.default_directory": DOWNLOADS_DIR,
        "download.prompt_for_download": False,
    }
    options.add_experimental_option("prefs", prefs)

    try:
        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=options)
        return driver
    except Exception as e:
        print(f"Chrome failed: {e}")
        print("Trying Firefox...")
        from selenium.webdriver.firefox.service import Service as FFService
        from webdriver_manager.firefox import GeckoDriverManager
        driver = webdriver.Firefox(service=FFService(GeckoDriverManager().install()))
        return driver

def wait_and_click(driver, by, value, timeout=10):
    """Wait for element and click it"""
    element = WebDriverWait(driver, timeout).until(
        EC.element_to_be_clickable((by, value))
    )
    element.click()
    return element

def wait_and_type(driver, by, value, text, timeout=10):
    """Wait for element and type into it"""
    element = WebDriverWait(driver, timeout).until(
        EC.presence_of_element_located((by, value))
    )
    element.clear()
    element.send_keys(text)
    return element

def create_oauth_client(driver):
    """Navigate and create OAuth client"""

    # Go to OAuth client creation page
    url = f"https://console.cloud.google.com/apis/credentials/oauthclient?project={PROJECT_ID}"
    print(f"[1/6] Opening: {url}")
    driver.get(url)
    time.sleep(3)

    # Check if we need to login
    if "accounts.google.com" in driver.current_url:
        print("[!] Please log in to Google in the browser window...")
        print("    Waiting for login to complete...")
        WebDriverWait(driver, 120).until(
            lambda d: "console.cloud.google.com" in d.current_url
        )
        print("[OK] Login detected, continuing...")
        time.sleep(2)

    # Select Desktop app from dropdown
    print("[2/6] Selecting 'Desktop app'...")
    try:
        # Click application type dropdown
        dropdown = WebDriverWait(driver, 15).until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, "mat-select[formcontrolname='applicationType'], [aria-label*='Application type']"))
        )
        dropdown.click()
        time.sleep(1)

        # Select Desktop app
        desktop_option = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//mat-option[contains(., 'Desktop app')]"))
        )
        desktop_option.click()
        time.sleep(1)
    except Exception as e:
        print(f"    Dropdown method failed: {e}")
        print("    Trying alternative selectors...")
        # Try clicking by text
        driver.find_element(By.XPATH, "//*[contains(text(), 'Desktop app')]").click()

    # Enter name
    print("[3/6] Entering name 'sashi-cli'...")
    try:
        name_input = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[formcontrolname='displayName'], input[aria-label*='Name']"))
        )
        name_input.clear()
        name_input.send_keys("sashi-cli")
    except:
        # Fallback
        inputs = driver.find_elements(By.TAG_NAME, "input")
        for inp in inputs:
            if inp.get_attribute("type") == "text":
                inp.clear()
                inp.send_keys("sashi-cli")
                break

    time.sleep(1)

    # Click Create button
    print("[4/6] Clicking CREATE...")
    try:
        create_btn = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, "//button[contains(., 'Create') or contains(., 'CREATE')]"))
        )
        create_btn.click()
    except:
        # Try by mat-button
        driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()

    time.sleep(3)

    # Wait for and click Download JSON
    print("[5/6] Waiting for popup and clicking DOWNLOAD JSON...")
    try:
        download_btn = WebDriverWait(driver, 15).until(
            EC.element_to_be_clickable((By.XPATH, "//button[contains(., 'Download') or contains(., 'DOWNLOAD')]"))
        )
        download_btn.click()
        print("[OK] Download initiated!")
    except Exception as e:
        print(f"    Could not find download button: {e}")
        print("    Check browser for manual download...")

    time.sleep(3)

    # Find and move the downloaded file
    print("[6/6] Moving credentials file...")
    json_files = glob.glob(os.path.join(DOWNLOADS_DIR, "client_secret*.json"))
    if json_files:
        latest = max(json_files, key=os.path.getctime)
        dest = os.path.join(CONFIG_DIR, "credentials.json")
        os.rename(latest, dest)
        print(f"[SUCCESS] Credentials saved to: {dest}")
        return True
    else:
        print("[!] No credentials file found in Downloads")
        print("    Check browser and manually download if needed")
        return False

def main():
    print("=" * 50)
    print("Gmail OAuth Browser Automation")
    print("=" * 50)
    print()

    driver = None
    try:
        print("Starting browser...")
        driver = setup_driver()
        driver.maximize_window()

        success = create_oauth_client(driver)

        if success:
            print()
            print("=" * 50)
            print("SETUP COMPLETE!")
            print("Now run: ~/ollama-local/mcp/gmail/tools/gmail-setup")
            print("=" * 50)
        else:
            print()
            print("Manual step needed - check browser window")
            input("Press Enter when done downloading...")

            # Try to find file again
            json_files = glob.glob(os.path.join(DOWNLOADS_DIR, "client_secret*.json"))
            if json_files:
                latest = max(json_files, key=os.path.getctime)
                dest = os.path.join(CONFIG_DIR, "credentials.json")
                os.rename(latest, dest)
                print(f"Credentials saved to: {dest}")

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

    finally:
        if driver:
            input("Press Enter to close browser...")
            driver.quit()

if __name__ == "__main__":
    main()
