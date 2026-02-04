# MacSnap Permissions Security Audit

**Audit Date**: 2026-02-02
**Version Reviewed**: 1.0.0
**Auditor**: Claude Code

## Executive Summary

MacSnap is a macOS screenshot utility that requires elevated permissions for core functionality. The permissions implementation is **generally sound** with a few areas for improvement. No critical security vulnerabilities were identified.

**Overall Assessment**: ✅ PASS with recommendations

---

## Permissions Required

| Permission | Purpose | Implementation |
|------------|---------|----------------|
| Screen Recording | Capture screenshots | ScreenCaptureKit (macOS 12.3+) |
| Accessibility | Global hotkeys | CGEvent tap system |
| Notifications | Capture notifications | UNUserNotificationCenter |

---

## Detailed Findings

### 1. Screen Recording Permission

**Files**: `CaptureEngine.swift:16-76`

#### Implementation Review

```swift
// Permission check - GOOD
public func hasScreenCapturePermission() -> Bool {
    if #available(macOS 10.15, *) {
        return CGPreflightScreenCaptureAccess()
    }
    // Fallback for older macOS...
}

// Permission request - GOOD
public func requestScreenCapturePermission() {
    if #available(macOS 12.3, *) {
        SCShareableContent.getExcludingDesktopWindows(...)
    }
}
```

**Findings**:
- ✅ Uses modern `CGPreflightScreenCaptureAccess()` API (macOS 10.15+)
- ✅ Uses ScreenCaptureKit for permission dialog trigger (required for macOS 14+)
- ✅ Proper fallback chain for older macOS versions
- ⚠️ **Minor**: No retry mechanism if user dismisses the dialog

**Recommendation**: Consider adding a periodic re-check (e.g., on first capture attempt) to re-prompt users who dismissed the initial dialog.

---

### 2. Accessibility Permission

**Files**: `HotkeyManager.swift:64-102`

#### Implementation Review

```swift
public func hasAccessibilityPermission() -> Bool {
    // First check standard API
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
    let axTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

    if !axTrusted { return false }

    // Verify by actually creating event tap
    let testTap = CGEvent.tapCreate(...)
    // ...
}
```

**Findings**:
- ✅ Uses `AXIsProcessTrustedWithOptions` correctly (non-prompting check)
- ✅ **Excellent**: Verifies permission by actually creating test event tap
- ✅ Properly cleans up test event tap after verification
- ✅ Uses `kAXTrustedCheckOptionPrompt: true` only when requesting

**This is a robust implementation** that handles edge cases where the AX database might return stale results.

---

### 3. Entitlements Configuration

**File**: `Resources/macsnap.entitlements`

```xml
<key>com.apple.security.app-sandbox</key>
<false/>

<key>com.apple.security.cs.disable-library-validation</key>
<true/>

<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>

<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

**Findings**:

| Entitlement | Status | Justification |
|-------------|--------|---------------|
| `app-sandbox: false` | ⚠️ Expected | Required for screen capture and global hotkeys |
| `disable-library-validation` | ❌ **Unnecessary** | No dynamic library loading detected |
| `allow-unsigned-executable-memory` | ❌ **Unnecessary** | No JIT or dynamic code execution detected |
| `files.user-selected.read-write` | ✅ OK | Needed for saving screenshots |
| `files.downloads.read-write` | ✅ OK | Common save location |

**Critical Recommendation**: Remove unnecessary entitlements:

```xml
<!-- REMOVE these - not needed -->
<key>com.apple.security.cs.disable-library-validation</key>
<true/>

<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
```

These entitlements weaken security without providing any benefit. The app does not:
- Load unsigned dynamic libraries
- Execute JIT-compiled or dynamically generated code

---

### 4. Permission Request Flow

**File**: `AppDelegate.swift:77-107`

```swift
private func checkPermissions() {
    let hasScreenRecording = CaptureEngine.shared.hasScreenCapturePermission()
    let hasAccessibility = HotkeyManager.shared.hasAccessibilityPermission()

    if !hasAccessibility {
        HotkeyManager.shared.requestAccessibilityPermission()
    }

    if !hasScreenRecording {
        // Delay to allow accessibility dialog first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            CaptureEngine.shared.requestScreenCapturePermission()
        }
    }

    requestNotificationPermission()
}
```

**Findings**:
- ✅ Checks both permissions at startup
- ✅ Requests accessibility first (simpler dialog)
- ⚠️ **Fragile**: Uses fixed 1-second delay between permission requests
- ⚠️ **Missing**: No user feedback if permissions are denied after initial setup

**Recommendations**:

1. **Replace fixed delay with completion-based sequencing** (if possible)
2. **Add permission status monitoring** to detect when user grants permission later
3. **Improve error handling**: Show actionable alert when capture fails due to missing permissions

---

### 5. Event Tap Security

**File**: `HotkeyManager.swift:106-155`

```swift
private func setupEventTap() {
    guard hasAccessibilityPermission() else {
        requestAccessibilityPermission()
        return
    }

    let eventMask = (1 << CGEventType.keyDown.rawValue)

    eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,  // Can consume events
        eventsOfInterest: CGEventMask(eventMask),
        callback: callback,
        userInfo: refcon
    )
}
```

**Findings**:
- ✅ Permission check before creating tap
- ✅ Uses session-level tap (appropriate for this use case)
- ✅ Only listens for keyDown events (minimal scope)
- ✅ Event consumption is selective (only registered hotkeys)

**Security Note**: The use of `.defaultTap` (which can consume events) is appropriate here since the app needs to prevent hotkey keypresses from reaching other applications.

---

### 6. Pre-capture Image Handling

**File**: `HotkeyManager.swift:195-213`

```swift
// Pre-capture screen to preserve hover states
DispatchQueue.global(qos: .userInteractive).async { [weak self] in
    var preCapturedImages: [CGDirectDisplayID: CGImage] = [:]

    if CGDisplayCreateImage(...) != nil {
        preCapturedImages = self?.captureAllDisplays() ?? [:]
    }

    DispatchQueue.main.async { [weak self] in
        self?.pendingCapturedImages = preCapturedImages
        self?.handlers[mode]?()
    }
}
```

**Findings**:
- ✅ Permission check before pre-capture
- ✅ Uses weak self to prevent retain cycles
- ⚠️ **Memory**: Pre-captured images are stored as `CGImage` in memory
- ✅ Images are cleared after capture via `clearPendingCaptures()`

**Recommendation**: Consider adding a timeout to clear pending captures if they're not used within a few seconds (e.g., user cancels selection).

---

## Security Recommendations Summary

### High Priority

1. **Remove unnecessary entitlements** from `macsnap.entitlements`:
   - `com.apple.security.cs.disable-library-validation`
   - `com.apple.security.cs.allow-unsigned-executable-memory`

### Medium Priority

2. **Add permission retry logic** for users who dismiss the initial dialog
3. **Add timeout for pre-captured images** to free memory if not used

### Low Priority

4. **Replace fixed timing delay** in permission request sequencing
5. **Add permission status change observer** (optional, for better UX)

---

## Code Quality Notes

The permissions implementation follows macOS best practices:
- Uses modern APIs (ScreenCaptureKit, CGPreflightScreenCaptureAccess)
- Properly handles API availability across macOS versions
- Event tap implementation is secure and well-scoped
- No hardcoded credentials or sensitive data exposure

---

## Compliance

| Requirement | Status |
|-------------|--------|
| Privacy manifest (macOS 14+) | ⚠️ Consider adding |
| Usage descriptions in Info.plist | ✅ Present |
| Hardened runtime | ✅ Enabled |
| Code signing | ✅ Implemented |

---

*This audit was performed by analyzing source code. Runtime testing was not performed.*
