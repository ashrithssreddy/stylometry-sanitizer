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

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainer?.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.drawsBackground = true

        context.coordinator.textView = textView

        // Add keyboard shortcut monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.charactersIgnoringModifiers == "n" {
                context.coordinator.neutralizeSelectedText()
                return nil // Consume the event
            }
            return event
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }

        DispatchQueue.main.async {
            if nsView.window?.firstResponder !== textView {
                nsView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorWithSelection
        weak var textView: NSTextView?

        init(_ parent: TextEditorWithSelection) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
            }
        }

        func neutralizeSelectedText() {
            guard let textView = textView else { return }
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