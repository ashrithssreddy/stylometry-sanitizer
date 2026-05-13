import AppKit
import Foundation

enum SelectionNeutralizerError: LocalizedError {
    case notTrusted
    case noFocusedElement
    case noSelectedText
    case replacementFailed

    var errorDescription: String? {
        switch self {
        case .notTrusted:
            return "Accessibility permission is required to neutralize text in other apps. Enable it in System Settings > Privacy & Security > Accessibility."
        case .noFocusedElement:
            return "Could not find the currently focused text element."
        case .noSelectedText:
            return "No selected text was found in the focused element."
        case .replacementFailed:
            return "Could not replace the selected text in the focused element."
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
            print("Accessibility permission required for neutralizing external text fields.")
            return
        }

        do {
            let element = try AccessibilityHelper.focusedUIElement()
            let selectedText = try AccessibilityHelper.selectedText(from: element)
            let rewritten = try await LLMService.rewrite(text: selectedText)
            try AccessibilityHelper.replaceSelectedText(in: element, with: rewritten)
            print("Neutralized selection successfully.")
        } catch {
            print("Neutralize failed: \(error.localizedDescription)")
        }
    }
}

private enum AccessibilityHelper {
    static func focusedUIElement() throws -> AXUIElement {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value)

        guard error == .success, let value = value else {
            throw SelectionNeutralizerError.noFocusedElement
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func selectedText(from element: AXUIElement) throws -> String {
        var value: CFTypeRef?
        let selectedError = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        if selectedError == .success, let text = value as? String, !text.isEmpty {
            return text
        }

        let valueError = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        if valueError == .success, let text = value as? String, !text.isEmpty {
            return text
        }

        throw SelectionNeutralizerError.noSelectedText
    }

    static func replaceSelectedText(in element: AXUIElement, with text: String) throws {
        let newValue = text as CFTypeRef
        let selectedError = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newValue)
        if selectedError == .success {
            return
        }

        let valueError = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue)
        if valueError == .success {
            return
        }

        throw SelectionNeutralizerError.replacementFailed
    }
}
