import Foundation
import Carbon
import AppKit

/// Manages global hotkey registration and handling
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var registeredHotkeys: [HotkeyBinding] = []

    /// Callback type for hotkey triggers
    public typealias HotkeyHandler = () -> Void

    private var handlers: [CaptureMode: HotkeyHandler] = [:]

    /// Set to true when area selection is active to handle CMD+SHIFT+2 specially
    public var isAreaSelectionActive = false

    /// Handler to call when CMD+SHIFT+2 is pressed during area selection
    public var areaSelectionCaptureHandler: (() -> Void)?

    private init() {}

    // MARK: - Public API

    /// Registers all hotkeys from configuration
    public func registerHotkeys() {
        let config = ConfigManager.shared.config
        guard config.shortcuts.enabled else {
            Logger.debug("Shortcuts are disabled in config")
            unregisterAll()
            return
        }

        registeredHotkeys = [
            parseHotkey(config.shortcuts.fullScreen, mode: .fullScreen),
            parseHotkey(config.shortcuts.areaSelect, mode: .area),
            parseHotkey(config.shortcuts.windowCapture, mode: .window),
            parseHotkey(config.shortcuts.customRegion, mode: .custom)
        ].compactMap { $0 }

        Logger.debug("Registered \(registeredHotkeys.count) hotkeys")
        for binding in registeredHotkeys {
            Logger.debug("  - \(binding.mode.rawValue): keyCode=\(binding.keyCode), modifiers=\(binding.modifiers)")
        }

        setupEventTap()
    }

    /// Sets handler for a capture mode
    public func setHandler(for mode: CaptureMode, handler: @escaping HotkeyHandler) {
        handlers[mode] = handler
    }

    /// Removes all hotkey registrations
    public func unregisterAll() {
        removeEventTap()
        registeredHotkeys.removeAll()
        handlers.removeAll()
    }

    /// Checks if accessibility permission is granted
    /// Uses AXIsProcessTrusted first, then verifies by attempting to create an event tap
    public func hasAccessibilityPermission() -> Bool {
        // First check the standard API
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let axTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // If AX says not trusted, definitely not trusted
        if !axTrusted {
            return false
        }

        // Verify by actually trying to create an event tap
        // This catches cases where AX returns stale/incorrect results
        let testTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Use listenOnly to avoid interfering
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )

        if let tap = testTap {
            // Successfully created tap - we have permission
            // Clean up the test tap immediately
            CGEvent.tapEnable(tap: tap, enable: false)
            return true
        }

        // Could not create event tap despite AX saying trusted
        return false
    }

    /// Requests accessibility permission
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Event Tap

    private func setupEventTap() {
        Logger.debug("Setting up event tap for global hotkeys...")

        // Remove existing tap if any
        removeEventTap()

        guard hasAccessibilityPermission() else {
            Logger.debug("Accessibility permission NOT granted - hotkeys will not work")
            requestAccessibilityPermission()
            return
        }

        Logger.debug("Accessibility permission granted")

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
            if manager.handleKeyEvent(event) {
                return nil // Consume the event
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: refcon
        )

        guard let tap = eventTap else {
            Logger.error("Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Logger.debug("Event tap created and enabled successfully")
    }

    private func removeEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handleKeyEvent(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Extract modifier flags
        let modifiers = extractModifiers(from: flags)

        // Check against registered hotkeys
        for binding in registeredHotkeys {
            if binding.keyCode == Int(keyCode) && binding.modifiers == modifiers {
                // Special handling: if area selection is active and this is the area hotkey,
                // trigger the capture instead of starting a new selection
                if isAreaSelectionActive && binding.mode == .area {
                    if let captureHandler = areaSelectionCaptureHandler {
                        DispatchQueue.main.async {
                            captureHandler()
                        }
                        return true // Consume the event
                    }
                }

                // Capture the mode before async dispatch
                let mode = binding.mode

                // Move pre-capture to a high-priority background queue to avoid blocking event tap
                // Event tap callback must return quickly or system becomes unresponsive
                DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                    // Pre-capture screen to preserve hover states
                    // Only capture if we have permission (otherwise images will be blank)
                    var preCapturedImages: [CGDirectDisplayID: CGImage] = [:]

                    // Quick permission check - try to capture 1x1 pixel
                    if CGDisplayCreateImage(CGMainDisplayID(), rect: CGRect(x: 0, y: 0, width: 1, height: 1)) != nil {
                        preCapturedImages = self?.captureAllDisplays() ?? [:]
                    }

                    DispatchQueue.main.async { [weak self] in
                        self?.pendingCapturedImages = preCapturedImages
                        self?.handlers[mode]?()
                    }
                }
                return true // Consume the event
            }
        }

        return false
    }

    /// Captures all displays immediately (thread-safe, called from event tap)
    private func captureAllDisplays() -> [CGDirectDisplayID: CGImage] {
        var images: [CGDirectDisplayID: CGImage] = [:]

        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetActiveDisplayList(16, &displayIDs, &displayCount)

        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            if let image = CGDisplayCreateImage(displayID) {
                images[displayID] = image
            }
        }

        return images
    }

    /// Stores pre-captured images for all displays to preserve hover states
    public var pendingCapturedImages: [CGDirectDisplayID: CGImage] = [:]

    /// Clears pending captured images
    public func clearPendingCaptures() {
        pendingCapturedImages.removeAll()
    }

    // MARK: - Hotkey Parsing

    private func parseHotkey(_ shortcut: String, mode: CaptureMode) -> HotkeyBinding? {
        let components = shortcut.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        guard !components.isEmpty else { return nil }

        var modifiers: Set<Modifier> = []
        var keyCode: Int?

        for component in components {
            switch component {
            case "cmd", "command", "⌘":
                modifiers.insert(.command)
            case "shift", "⇧":
                modifiers.insert(.shift)
            case "alt", "option", "opt", "⌥":
                modifiers.insert(.option)
            case "ctrl", "control", "⌃":
                modifiers.insert(.control)
            default:
                // Assume it's a key
                keyCode = keyCodeForCharacter(component)
            }
        }

        guard let code = keyCode else { return nil }

        return HotkeyBinding(keyCode: code, modifiers: modifiers, mode: mode)
    }

    private func extractModifiers(from flags: CGEventFlags) -> Set<Modifier> {
        var modifiers: Set<Modifier> = []

        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }

        return modifiers
    }

    private func keyCodeForCharacter(_ char: String) -> Int? {
        let keyCodeMap: [String: Int] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, "space": 49, "return": 36,
            "tab": 48, "delete": 51, "escape": 53, "esc": 53,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111
        ]

        return keyCodeMap[char.lowercased()]
    }
}

/// Represents a registered hotkey binding
struct HotkeyBinding {
    let keyCode: Int
    let modifiers: Set<Modifier>
    let mode: CaptureMode
}

/// Modifier key flags
enum Modifier: Hashable {
    case command
    case shift
    case option
    case control
}

// MARK: - Shortcut Formatting

extension HotkeyManager {
    /// Formats a shortcut string for display
    public static func formatShortcut(_ shortcut: String) -> String {
        var result = ""
        let components = shortcut.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        for component in components {
            switch component {
            case "cmd", "command":
                result += "⌘"
            case "shift":
                result += "⇧"
            case "alt", "option", "opt":
                result += "⌥"
            case "ctrl", "control":
                result += "⌃"
            default:
                result += component.uppercased()
            }
        }

        return result
    }

    /// Validates a shortcut string
    public static func isValidShortcut(_ shortcut: String) -> Bool {
        let components = shortcut.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        guard components.count >= 2 else { return false } // Need at least modifier + key

        var hasModifier = false
        var hasKey = false

        let modifiers = ["cmd", "command", "shift", "alt", "option", "opt", "ctrl", "control", "⌘", "⇧", "⌥", "⌃"]

        for component in components {
            if modifiers.contains(component) {
                hasModifier = true
            } else {
                hasKey = true
            }
        }

        return hasModifier && hasKey
    }
}
