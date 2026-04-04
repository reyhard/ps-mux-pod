---
name: flutter-windows-build-fixes
description: Use when Flutter Android builds fail on Windows with Kotlin daemon errors, cross-drive cache corruption, missing Developer Mode, or signing keystore issues
---

# Flutter Windows Build Fixes

## Overview

Windows-specific Flutter build failures in this project. Project lives on `O:` drive while pub cache is on `C:`, causing Kotlin cross-drive issues.

## Quick Reference

| Symptom | Fix |
|---------|-----|
| `Building with plugins requires symlink support` | Enable Developer Mode: `start ms-settings:developers` |
| `Daemon compilation failed: null` + `different roots` | `kotlin.incremental=false` in `android/gradle.properties` (already set) |
| `signingConfigData.storeFile ... doesn't exist` | Use `--debug` or `--profile` instead of `--release` |
| Stale cache errors | `flutter clean && cd android && ./gradlew clean && cd .. && flutter pub get` |

## Build Commands

```bash
flutter build apk --debug      # Full debug (~174MB)
flutter build apk --profile    # Optimized, debug-signed (~99MB)
flutter build apk --release    # Requires upload-keystore.jks (not in repo)
```

## ADB Install

```
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Debugging on Device

```
adb logcat -s flutter                              # All Flutter logs
adb logcat | findstr "Terminal MuxDetector"         # Mux detection logs
```
