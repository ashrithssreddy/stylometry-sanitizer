import SwiftUI
import AppKit

@main
struct StylometrySanitizerApp: App {
    @StateObject private var neutralizer = SelectionNeutralizer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Neutralize") {
                Button("Neutralize Selection") {
                    Task {
                        await neutralizer.neutralizeFocusedSelection()
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .option, .shift])
            }
        }
    }

    init() {
        NSApplication.shared.servicesProvider = self
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
}

extension StylometrySanitizerApp {
    func neutralizeText(_ pasteboard: NSPasteboard, userData: String?, error: NSErrorPointer) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error?.pointee = NSError(domain: "NeutralizeText", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text found"])
            return
        }

        Task {
            do {
                let rewritten = try await LLMService.rewrite(text: text, model: LLMService.preferredModel())
                pasteboard.clearContents()
                pasteboard.setString(rewritten, forType: .string)
            } catch let caughtError {
                DispatchQueue.main.async {
                    error?.pointee = NSError(domain: "NeutralizeText", code: 2, userInfo: [NSLocalizedDescriptionKey: caughtError.localizedDescription])
                }
            }
        }
    }
}
