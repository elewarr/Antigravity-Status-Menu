---
description: Prepare Antigravity Stats Menu for macOS distribution
---

# Prepare macOS Release

This workflow prepares Antigravity Stats Menu for distribution.

## Prerequisites

- Xcode with valid signing certificates
- All feature development complete

## Steps

### 1. Update Version Numbers

Edit version in Xcode project or:

```bash
# Check current version
grep -A1 "MARKETING_VERSION" "Antigravity Stats Menu.xcodeproj/project.pbxproj" | head -4
grep -A1 "CURRENT_PROJECT_VERSION" "Antigravity Stats Menu.xcodeproj/project.pbxproj" | head -4
```

Update via Xcode: Project → Antigravity Stats Menu → General → Identity

### 2. Run All Tests

// turbo
```bash
xcodebuild test -project "Antigravity Stats Menu.xcodeproj" -scheme "Antigravity Stats Menu" \
  -destination "platform=macOS" 2>&1 | tail -20
```

### 3. Run SwiftLint

// turbo
```bash
swiftlint --fix && swiftlint
```

### 4. Build for macOS

// turbo
```bash
xcodebuild build -project "Antigravity Stats Menu.xcodeproj" -scheme "Antigravity Stats Menu" \
  -destination "platform=macOS" -quiet && echo "✅ macOS build passed"
```

### 5. Check Entitlements

// turbo
```bash
cat "Antigravity Stats Menu/Antigravity_Stats_Menu.entitlements"
```

Verify sandbox and required entitlements are present.

### 6. Archive for Distribution

```bash
xcodebuild archive -project "Antigravity Stats Menu.xcodeproj" -scheme "Antigravity Stats Menu" \
  -archivePath build/AntigravityStatsMenu.xcarchive
```

### 7. Export for Distribution

For Developer ID (direct distribution):
```bash
xcodebuild -exportArchive -archivePath build/AntigravityStatsMenu.xcarchive \
  -exportPath build/Release -exportOptionsPlist ExportOptions.plist
```

## Checklist

- [ ] Version number incremented
- [ ] All tests passing
- [ ] SwiftLint clean
- [ ] Build succeeds
- [ ] Entitlements correct
- [ ] Archive created
- [ ] Export complete
