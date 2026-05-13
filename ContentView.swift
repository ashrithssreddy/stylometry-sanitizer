import SwiftUI

struct ContentView: View {
    @State private var text = "Type or paste your text here. Highlight text and press Cmd+Shift+N to neutralize."

    var body: some View {
        VStack {
            TextEditorWithSelection(text: $text)
                .font(.system(.body, design: .default))
                .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct TextEditorWithSelection: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.delegate = context.coordinator

        // Add keyboard shortcut monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.charactersIgnoringModifiers == "n" {
                context.coordinator.neutralizeSelectedText(in: textView)
                return nil // Consume the event
            }
            return event
        }

        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorWithSelection

        init(_ parent: TextEditorWithSelection) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
            }
        }

        func neutralizeSelectedText(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0 else { return }

            let selectedText = (textView.string as NSString).substring(with: selectedRange)

            Task {
                do {
                    let rewritten = try await LLMService.rewrite(text: selectedText)
                    // Replace the selected text with rewritten
                    await MainActor.run {
                        textView.replaceCharacters(in: selectedRange, with: rewritten)
                        parent.text = textView.string
                    }
                } catch {
                    // Show error alert
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Error"
                        alert.informativeText = "Failed to rewrite text: \(error.localizedDescription)"
                        alert.runModal()
                    }
                }
            }
        }
    }
}