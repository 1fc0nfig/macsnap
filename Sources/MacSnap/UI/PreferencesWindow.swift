import AppKit

final class PreferencesWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == [.command],
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "q":
            NSApp.terminate(nil)
            return true
        case "o":
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.openOutputFolder()
                return true
            }
            return false
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
