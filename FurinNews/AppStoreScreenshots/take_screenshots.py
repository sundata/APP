#!/usr/bin/env python3
"""
App Store Screenshot Generator for ニュースNow v4
Uses precise screen coordinates with iterative refinement.
"""

import subprocess
import time
import os
import sys
import pyautogui

SIMULATOR_ID = "595A70BF-AB23-4C44-8090-41194093266F"
BUNDLE_ID = "com.sundata.newsnow"
OUTPUT_DIR = "/Users/sundata/WorkBuddy/20260412212940/FurinNews/AppStoreScreenshots"

# Simulator window position
WIN_X, WIN_Y = 808, 48
WIN_W, WIN_H = 336, 732
TITLE_BAR = 28

CONTENT_Y_START = WIN_Y + TITLE_BAR  # y=76
CONTENT_H = WIN_H - TITLE_BAR  # 704

# Scale factors (sim points to screen pixels)
SCALE_X = WIN_W / 430   # 0.781
SCALE_Y = CONTENT_H / 932  # 0.755

def sim_to_screen(sim_x, sim_y):
    """Convert simulator point coordinates to screen pixel coordinates."""
    screen_x = int(WIN_X + sim_x * SCALE_X)
    screen_y = int(CONTENT_Y_START + sim_y * SCALE_Y)
    return screen_x, screen_y

def run_cmd(cmd, timeout=30):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return result.stdout.strip(), result.stderr.strip(), result.returncode

def take_screenshot(name):
    path = os.path.join(OUTPUT_DIR, name)
    cmd = f"xcrun simctl io {SIMULATOR_ID} screenshot '{path}'"
    stdout, stderr, code = run_cmd(cmd)
    status = "✓" if code == 0 else "✗"
    print(f"  {status} {name}")
    return path

def activate_simulator():
    subprocess.run(["osascript", "-e", 'tell application "Simulator" to activate'], 
                   capture_output=True)
    time.sleep(0.5)

def tap(sim_x, sim_y, description=""):
    """Tap at simulator point coordinates."""
    screen_x, screen_y = sim_to_screen(sim_x, sim_y)
    activate_simulator()
    time.sleep(0.2)
    pyautogui.click(screen_x, screen_y)
    desc = f" - {description}" if description else ""
    print(f"  → Tap sim({sim_x},{sim_y}) → screen({screen_x},{screen_y}){desc}")

def get_md5(path):
    result = subprocess.run(f"md5 -q '{path}'", shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Clean up old numbered screenshots
    for f in os.listdir(OUTPUT_DIR):
        if f.endswith(".png") and f.startswith("0"):
            os.remove(os.path.join(OUTPUT_DIR, f))
    
    print("=" * 60)
    print("ニュースNow App Store Screenshot Generator v4")
    print(f"Window: ({WIN_X},{WIN_Y}) {WIN_W}x{WIN_H}")
    print(f"Scale: {SCALE_X:.3f}x{SCALE_Y:.3f}")
    print("=" * 60)
    
    # Step 1: Launch the app
    print("\n📱 Launching app...")
    run_cmd(f"xcrun simctl terminate {SIMULATOR_ID} {BUNDLE_ID}")
    time.sleep(1)
    stdout, stderr, code = run_cmd(f"xcrun simctl launch {SIMULATOR_ID} {BUNDLE_ID}")
    if code != 0:
        print(f"  ✗ Failed: {stderr}")
        sys.exit(1)
    print(f"  ✓ Launched (PID: {stdout})")
    
    # Wait for content
    print("\n⏳ Waiting for content...")
    time.sleep(12)
    
    # ===== Screenshot 1: Home Feed =====
    print("\n📸 [1/6] Home Feed")
    take_screenshot("01_home_feed.png")
    
    # ===== Screenshot 2: Article Detail =====
    # First, let's try tapping an article card
    # On iPhone, the first article card in a list typically starts around y=140pt
    # and extends to about y=350pt
    print("\n📸 [2/6] Article Detail")
    # Try tapping the center of the first visible article
    tap(215, 220, "first article")
    time.sleep(4)
    take_screenshot("02_article_detail.png")
    
    # Check if article opened (compare with home screenshot)
    md5_home = get_md5(os.path.join(OUTPUT_DIR, "01_home_feed.png"))
    md5_article = get_md5(os.path.join(OUTPUT_DIR, "02_article_detail.png"))
    
    if md5_home == md5_article:
        print("  ⚠ Article didn't open. Trying different Y coordinate...")
        # Try different Y positions for the article
        for y in [180, 260, 320, 380]:
            tap(215, y, f"article at y={y}")
            time.sleep(3)
            take_screenshot(f"02_article_detail_y{y}.png")
            md5_new = get_md5(os.path.join(OUTPUT_DIR, f"02_article_detail_y{y}.png"))
            if md5_new != md5_home:
                print(f"  ✓ Article opened at y={y}!")
                # Rename to final name
                os.rename(
                    os.path.join(OUTPUT_DIR, f"02_article_detail_y{y}.png"),
                    os.path.join(OUTPUT_DIR, "02_article_detail.png")
                )
                break
        else:
            print("  ⚠ Could not open article. Using home screenshot as fallback.")
    
    # Go back to home if article opened
    if md5_home != get_md5(os.path.join(OUTPUT_DIR, "02_article_detail.png")):
        print("  ← Going back to home...")
        # Try multiple ways to go back
        tap(20, 50, "back button")
        time.sleep(1)
        # If that doesn't work, try the "戻る" button area
        tap(30, 100, "alternative back")
        time.sleep(2)
    
    # ===== Screenshot 3-5: Other tabs =====
    # Tab bar layout: 5 tabs evenly spaced across 430pt width
    # Each tab occupies 86pt (430/5)
    # Tab centers: 43, 129, 215, 301, 387
    # Tab bar Y position: approximately 895-930pt (at the very bottom)
    # But the safe area might shift things, so let's use y=905
    
    tabs = [
        (1, "03_search.png", "検索", 129),
        (2, "04_categories.png", "カテゴリ", 215),
        (4, "05_settings.png", "設定", 387),
    ]
    
    for tab_idx, filename, tab_name, tab_x in tabs:
        print(f"\n📸 [{3 + tabs.index((tab_idx, filename, tab_name, tab_x))}/6] {tab_name} (Tab {tab_idx})")
        tap(tab_x, 905, f"tab {tab_name}")
        time.sleep(3)
        take_screenshot(filename)
    
    # ===== Screenshot 6: Paywall =====
    print("\n📸 [6/6] Paywall")
    # We should be on Settings tab
    # Tap "広告を削除" which is likely the first row in settings
    # Try a few positions
    tap(215, 250, "広告を削除 button")
    time.sleep(3)
    take_screenshot("06_paywall.png")
    
    # Check if paywall opened
    md5_settings = get_md5(os.path.join(OUTPUT_DIR, "05_settings.png"))
    md5_paywall = get_md5(os.path.join(OUTPUT_DIR, "06_paywall.png"))
    
    if md5_settings == md5_paywall:
        print("  ⚠ Paywall didn't open. Trying different positions...")
        for y in [200, 300, 350, 400, 450]:
            tap(215, y, f"paywall at y={y}")
            time.sleep(2)
            path = os.path.join(OUTPUT_DIR, "06_paywall.png")
            cmd = f"xcrun simctl io {SIMULATOR_ID} screenshot '{path}'"
            run_cmd(cmd)
            md5_new = get_md5(path)
            if md5_new != md5_settings:
                print(f"  ✓ Paywall opened at y={y}!")
                break
    
    # Print results
    print("\n" + "=" * 60)
    print("✅ Screenshot capture complete!")
    print(f"📁 {OUTPUT_DIR}")
    print("=" * 60)
    
    print("\n📊 Verification:")
    seen_hashes = {}
    for f in sorted(os.listdir(OUTPUT_DIR)):
        if f.endswith(".png") and f.startswith("0"):
            path = os.path.join(OUTPUT_DIR, f)
            h = get_md5(path)
            size = os.path.getsize(path) / 1024
            is_dup = "⚠ DUP" if h in seen_hashes else "✓"
            seen_hashes[h] = f
            print(f"  {f}: {size:.0f} KB {is_dup}")

if __name__ == "__main__":
    main()
