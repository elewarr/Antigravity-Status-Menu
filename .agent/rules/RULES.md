# Antigravity Stats Menu Project Rules

## Platform Target

This project targets **macOS only** (menu bar app):

| Platform | Minimum Version | Status |
|----------|-----------------|--------|
| macOS    | 12.0+          | ✅ Active |

---

## Code Organization

### Project Structure

```
Antigravity Stats Menu/
├── Controllers/      # AppKit controllers (StatusBarController)
├── Services/         # Business logic (QuotaService, CloudCodeService)
├── ViewModels/       # Observable view models
├── Views/            # SwiftUI views
├── Models/           # Data models
└── Utilities/        # Helpers and extensions
```

### Rules

1. **Pure AppKit for menu bar**: Use `NSStatusItem` and `NSPopover` patterns (no SwiftUI App lifecycle)
2. **SwiftUI for content**: Views inside popovers use SwiftUI
3. **Use @Observable**: Prefer modern Observable macro over ObservableObject for view models
4. **Separate concerns**: Keep services, view models, and views in their respective directories

---

## Quality Standards

### Code Quality Checklist

Before committing code, ensure:

- [ ] **SwiftLint passes** with no serious violations (`swiftlint`)
- [ ] **Builds on macOS** without warnings
- [ ] **Tests pass** for affected functionality

### Build Verification Commands

```bash
# macOS build
xcodebuild -project "Antigravity Stats Menu.xcodeproj" -scheme "Antigravity Stats Menu" \
  -destination 'platform=macOS' build

# Run SwiftLint
swiftlint
swiftlint --fix  # auto-correct
```

### ⚠️ MANDATORY: Pre-Push Testing

> [!CAUTION]
> **NEVER push code without running and passing ALL tests.**

Before ANY `git push`, the agent MUST:

1. **Build for testing**:
   ```bash
   xcodebuild build-for-testing -project "Antigravity Stats Menu.xcodeproj" \
     -scheme "Antigravity Stats Menu" -destination 'platform=macOS'
   ```

2. **Run SwiftLint** and fix violations:
   ```bash
   swiftlint --fix && swiftlint
   ```

3. **Verify test build succeeds** - if `** TEST BUILD SUCCEEDED **` is not shown, DO NOT PUSH.

**If any step fails, the agent must fix the issue before pushing.**

### ⚠️ MANDATORY: Multi-Agent Coordination

> [!CAUTION]
> **NEVER push code when another agent may be working on the same repository.**

Before pushing, the agent MUST check for concurrent work:

1. **Check for remote changes**:
   ```bash
   git fetch origin && git log HEAD..origin/main --oneline
   ```
   If there are new commits on remote, DO NOT PUSH until you pull and resolve.

2. **Check for uncommitted changes by others**:
   ```bash
   git status
   ```
   If you see changes you didn't make, another agent may be active. STOP and ask the user.

**If uncertain whether another agent is working, ASK the user before pushing.**

---

## Architecture Patterns

### StatusBarController Pattern

The app uses a Pure AppKit architecture for menu bar presence:

```swift
class StatusBarController: @unchecked Sendable {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    // ...
}
```

Key patterns:
- Single `NSStatusItem` instance
- `NSPopover` for content display
- Bridge to SwiftUI views using `NSHostingController`
- Use `withObservationTracking` for reactive updates from @Observable models

### Service Pattern

Services encapsulate business logic:

```swift
actor QuotaService {
    func fetchQuota() async throws -> QuotaData
}
```

Use actors for thread-safe state management.

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Types | PascalCase | `StatusBarController`, `QuotaViewModel` |
| Properties/Methods | camelCase | `statusItem`, `fetchQuota()` |
| Files | PascalCase | `StatusBarController.swift` |

---

## Dependencies

### Required Tools

| Tool | Purpose | Install |
|------|---------|---------|
| SwiftLint | Code style enforcement | `brew install swiftlint` |
| Xcode 14+ | Build & development | Mac App Store |

### External Dependencies

Currently **no external dependencies** - the project uses only Apple frameworks:
- SwiftUI
- AppKit
- Foundation
