# InputSourcePro 2.10.1 Test Plan

## Build & Package

### Prerequisites
- macOS 11+ (Big Sur or later)
- At least 2 input sources configured (e.g., ABC + Simplified Chinese Pinyin)
- Xcode command line tools installed

### Build Steps
```bash
# Tag and push to trigger GitHub Actions build
git tag 2.10.1
git push origin 2.10.1
```

### Verify Build
- [ ] GitHub Actions workflow completes successfully
- [ ] DMG artifact is generated
- [ ] DMG is notarized and stapled
- [ ] App launches without crash

---

## Core Input Method Memory Tests

### T1: Basic Per-App Input Source Memory (#83, #66)
1. Open Terminal, switch to Chinese input
2. Open TextEdit, switch to ABC
3. Switch back to Terminal
4. **Expected**: Chinese input is restored automatically
5. Switch back to TextEdit
6. **Expected**: ABC is restored automatically

### T2: Rapid App Switching (#68)
1. Set Terminal default to Chinese, TextEdit default to ABC
2. Rapidly switch between Terminal and TextEdit (10+ times in 5 seconds)
3. **Expected**: Input source always matches the app's default, no flickering

### T3: Input Source Memory Across Multiple Apps
1. Open 3+ apps with different input source settings
2. Switch between them in sequence
3. **Expected**: Each app remembers its last used input source

### T4: App Restart Persistence
1. Set up per-app input sources
2. Quit InputSourcePro
3. Relaunch InputSourcePro
4. Switch between apps
5. **Expected**: Default input sources are applied (cache is in-memory, so previous session is lost by design)

---

## CJKV Switching Tests

### T5: Chinese Input Source Activation (#85)
1. Set an app's default to Chinese Pinyin
2. Switch to that app from an ABC app
3. **Expected**: Chinese input is actually active (not just showing as switched)
4. Type immediately after switching
5. **Expected**: Characters are Chinese, not English

### T6: Temporary Input Window (#80, #97)
1. Enable "Temporary Input Window" CJKV fix strategy
2. Switch between apps with Chinese/English defaults
3. **Expected**: No emoji dialog appears (#80)
4. Disable all indicators
5. Switch between apps
6. **Expected**: No small square hint visible (#97)

### T7: Fullscreen App Switching (#103, #94)
1. Open a fullscreen app (e.g., Safari)
2. Switch to another app and back
3. **Expected**: No black bar, no screen tearing, smooth transition

### T8: CJKV Debounce (#92)
1. Use Vivaldi or Chrome browser
2. Set browser default to Chinese
3. Rapidly switch tabs and apps
4. **Expected**: No freeze, no deadlock

---

## Browser Rule Tests

### T9: Browser URL Detection
1. Enable browser rules for Chrome
2. Set a rule for a specific website (e.g., google.com -> Chinese)
3. Navigate to that website
4. **Expected**: Input source switches to Chinese

### T10: ChatGPT Atlas Support (#90, #65)
1. Install ChatGPT Atlas browser
2. Enable browser rules for ChatGPT Atlas
3. Set a rule for a website
4. Navigate to that website in Atlas
5. **Expected**: Input source switches according to the rule

### T11: Browser Context Cache
1. Open Chrome, navigate to site A (Chinese rule)
2. Switch to another app
3. Switch back to Chrome
4. **Expected**: Chinese input is restored immediately (not after 1-second delay)

### T12: ChatGPT Floating Window (#104)
1. Open ChatGPT app
2. Press Opt+Space to open floating window
3. Switch to another app and back
4. **Expected**: Input source switches correctly, no unexpected behavior

---

## Punctuation Tests

### T13: Force English Punctuation - Per App
1. Enable "Force English Punctuation" for Terminal
2. Switch to Chinese input in Terminal
3. Type ` , . ; ' [ ] \ `
4. **Expected**: All punctuation is English

### T14: Global Force English Punctuation (#109)
1. Enable "Force English Punctuation for All Apps" in General settings
2. Open any app with Chinese input
3. Type punctuation keys
4. **Expected**: All punctuation is English in all apps

### T15: Punctuation After Input Source Switch (#102)
1. Set an app to switch between ABC and Chinese
2. Switch from Chinese to ABC
3. Immediately press Shift+- (underscore)
4. **Expected**: Underscore `_` appears, not em dash `——`

### T16: Punctuation with Shift
1. Enable Force English Punctuation
2. With Chinese input active, type:
   - Shift+` → `~`
   - Shift+4 → `$`
   - Shift+6 → `^`
   - Shift+- → `_`
3. **Expected**: All shifted punctuation is correct English

---

## Shortcut Tests

### T17: Keyboard Shortcut Input Source Switch
1. Configure a keyboard shortcut for Chinese input
2. Press the shortcut
3. **Expected**: Input source switches to Chinese

### T18: Single Modifier Shortcut
1. Configure Left Shift as single-press trigger for input source switch
2. Press and release Left Shift
3. **Expected**: Input source switches

### T19: Shortcut Doesn't Trigger CJKV Bounce
1. Configure a shortcut for Chinese input
2. Press the shortcut
3. **Expected**: No brief flash of ABC before Chinese

---

## Indicator Tests

### T20: Indicator Shows on App Switch
1. Enable "Show when switching apps"
2. Switch between apps
3. **Expected**: Indicator appears showing current input source

### T21: Indicator Hidden When Configured
1. Set "Hide indicator" for a specific app
2. Switch to that app
3. **Expected**: No indicator appears

### T22: Always-On Indicator
1. Enable always-on indicator
2. Type in different apps
3. **Expected**: Indicator follows cursor position

---

## Edge Cases

### T23: System Sleep/Wake
1. Set per-app input sources
2. Put Mac to sleep
3. Wake up
4. Switch between apps
5. **Expected**: Input source memory still works

### T24: Screen Lock/Unlock
1. Set per-app input sources
2. Lock screen (Cmd+Ctrl+Q)
3. Unlock
4. Switch between apps
5. **Expected**: Input source memory still works

### T25: Multiple Desktops/Spaces
1. Set per-app input sources
2. Move apps to different Spaces
3. Switch between Spaces
6. **Expected**: Input source switches correctly per app

### T26: Floating Apps (Raycast, Alfred, Spotlight) (#67, #78)
1. Open Raycast or Alfred
2. Type immediately
3. **Expected**: No input lag, typing is responsive

---

## Settings Backup Tests

### T27: Export Settings
1. Configure per-app rules, browser rules, shortcuts
2. Export settings to JSON file
3. **Expected**: JSON file contains all settings

### T28: Import Settings
1. Import the exported JSON file
2. **Expected**: All settings are restored correctly

---

## Regression Tests

### T29: Basic App Switch (No Rules)
1. Don't set any per-app rules
2. Switch between apps
3. **Expected**: Input source stays as-is (no unexpected switching)

### T30: Default Keyboard Fallback
1. Set system-wide default to ABC
2. Open an app with no specific rule
3. **Expected**: ABC is used as default

---

## Known Limitations (Not Bugs)
- Input source cache is in-memory only; restarting the app loses per-session cache
- Caps Lock is not supported as a shortcut modifier key (by design)
- Chrome extension override pages may not be detected by browser rules (#42)
- Dictation language is controlled by macOS, not InputSourcePro (#23)
- CursorUIViewService memory issue is a macOS-level problem (#91/#55)
