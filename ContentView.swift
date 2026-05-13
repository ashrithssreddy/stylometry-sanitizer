import SwiftUI

struct ContentView: View {
    @State private var text = "Type or paste your text here. Press the button or Cmd+Option+Shift+L to neutralize."
    @State private var isProcessing = false
    @State private var alertMessage: String?
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Stylometry Sanitizer")
                .font(.title2)
                .bold()
                .padding(.top)

            TextEditor(text: $text)
                .focused($editorFocused)
                .font(.system(.body, design: .default))
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .contextMenu {
                    Button("Neutralize Text") {
                        neutralizeText()
                    }
                }
                .frame(minHeight: 280)

            HStack {
                Text("Current text is neutralizable inside this window. Use Cmd+Option+Shift+L for any focused text box when accessibility permission is granted.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: neutralizeText) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("Neutralize Text")
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .option, .shift])
                .disabled(isProcessing || text.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 640, minHeight: 460)
        .padding()
        .onAppear {
            editorFocused = true
        }
        .alert("Error", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    func neutralizeText() {
        guard !text.isEmpty else { return }
        isProcessing = true

        Task {
            do {
                let rewritten = try await LLMService.rewrite(text: text)
                await MainActor.run {
                    text = rewritten
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to rewrite text: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}
