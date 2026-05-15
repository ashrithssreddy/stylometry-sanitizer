import SwiftUI
import AppKit

@main
struct StylometrySanitizerApp: App {
    @StateObject private var neutralizer = SelectionNeutralizer()
    private static let serviceProvider = NeutralizeTextServiceProvider()

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
        NSApplication.shared.servicesProvider = Self.serviceProvider
        NSUpdateDynamicServices()
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
}

final class NeutralizeTextServiceProvider: NSObject {
    @objc(neutralizeText:userData:error:)
    func neutralizeText(_ pasteboard: NSPasteboard, userData: String?, error: NSErrorPointer) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error?.pointee = NSError(domain: "NeutralizeText", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text found"])
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error>?

        Task {
            do {
                let rewritten = try await LLMService.rewrite(text: text, model: LLMService.preferredModel())
                result = .success(rewritten)
            } catch let caughtError {
                result = .failure(caughtError)
            }

            semaphore.signal()
        }

        semaphore.wait()

        switch result {
        case .success(let rewritten):
            pasteboard.clearContents()
            pasteboard.setString(rewritten, forType: .string)
        case .failure(let caughtError):
            error?.pointee = NSError(domain: "NeutralizeText", code: 2, userInfo: [NSLocalizedDescriptionKey: caughtError.localizedDescription])
        case .none:
            error?.pointee = NSError(domain: "NeutralizeText", code: 3, userInfo: [NSLocalizedDescriptionKey: "Rewrite did not complete."])
        }
    }
}
