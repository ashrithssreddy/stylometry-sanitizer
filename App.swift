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
}
