import AppKit
import Foundation

enum SelectionNeutralizerError: LocalizedError {
    case notTrusted
    case noSelection
    case clipboardError
    case rewriteFailed

    var errorDescription: String? {
        switch self {
        case .notTrusted:
            return "Accessibility permission is required to neutralize text in other apps. Enable it in System Settings > Privacy & Security > Accessibility."
        case .noSelection:
            return "No selected text was found in the focused app."
        case .clipboardError:
            return "Failed to access the clipboard."
        case .rewriteFailed:
            return "Failed to rewrite the copied text."
        }
    }
}

final class SelectionNeutralizer: ObservableObject {
    private var globalMonitor: Any?

    init() {
        requestAccessibilityPermissionIfNeeded()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let hasModifiers = event.modifierFlags.contains(.command) && event.modifierFlags.contains(.option) && event.modifierFlags.contains(.shift)
            if hasModifiers, event.charactersIgnoringModifiers?.lowercased() == "l" {
                Task {
                    await self?.neutralizeFocusedSelection()
                }
            }
        }
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func ensureAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func neutralizeFocusedSelection() async {
        guard ensureAccessibilityPermission() else {
            print("Accessibility permission required for external neutralization.")
            return
        }

        do {
            let originalClipboardItems = NSPasteboard.general.pasteboardItems
            let selectedText = try copySelectedText()
            let rewritten = try await LLMService.rewrite(text: selectedText)
            try pasteText(rewritten)
            restoreClipboardItems(originalClipboardItems)
            print("Neutralized selection successfully.")
        } catch {
            print("Neutralize failed: \(error.localizedDescription)")
        }
    }

    private func copySelectedText() throws -> String {
        guard let system = CGEventSource(stateID: .combinedSessionState) else {
            throw SelectionNeutralizerError.clipboardError
        }

        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems

        // Request the active app to copy the current selection
        sendCommandKeyPress(keyCode: 8, source: system) // Cmd+C
        usleep(200_000)

        guard let copiedText = pasteboard.string(forType: .string), !copiedText.isEmpty else {
            restoreClipboardItems(originalItems)
            throw SelectionNeutralizerError.noSelection
        }

        return copiedText
    }

    private func pasteText(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems

        let cleared = pasteboard.clearContents()
        guard cleared != 0 else {
            throw SelectionNeutralizerError.clipboardError
        }

        let wrote = pasteboard.setString(text, forType: .string)
        guard wrote else {
            restoreClipboardItems(originalItems)
            throw SelectionNeutralizerError.clipboardError
        }

        guard let system = CGEventSource(stateID: .combinedSessionState) else {
            restoreClipboardItems(originalItems)
            throw SelectionNeutralizerError.clipboardError
        }

        sendCommandKeyPress(keyCode: 9, source: system) // Cmd+V
        usleep(200_000)
        restoreClipboardItems(originalItems)
    }

    private func restoreClipboardItems(_ items: [NSPasteboardItem]?) {
        guard let items = items, !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    private func sendCommandKeyPress(keyCode: CGKeyCode, source: CGEventSource) {
        let flags = CGEventFlags.maskCommand
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
