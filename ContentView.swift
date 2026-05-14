import SwiftUI

struct ContentView: View {
    @State private var originalText = "Type or paste your text here. Press Neutralize to see the before and after text."
    @State private var neutralizedText = ""
    @State private var selectedModel = LLMService.preferredModel()
    @State private var availableModels: [String] = []
    @State private var beforeSelectedRange = NSRange(location: 0, length: 0)
    @State private var afterSelectedRange = NSRange(location: 0, length: 0)
    @State private var newModelName = ""
    @State private var isLoadingModels = true
    @State private var isInstallingModel = false
    @State private var modelLoadError: String?
    @State private var isProcessing = false
    @State private var alertMessage: String?
    @State private var didCopyOutput = false
    @FocusState private var originalFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.windowBackgroundColor).opacity(0.95)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("🛡️ Stylometry Sanitizer")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Neutralize your writing style for privacy")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)

                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 20) {
                        textPanel(title: "Original Text", text: $originalText, isEditable: true, selectedRange: $beforeSelectedRange)
                        textPanel(title: "Sanitized Text", text: $neutralizedText, isEditable: false, selectedRange: $afterSelectedRange)
                    }
                    .frame(minHeight: 350)

                    HStack(alignment: .center, spacing: 12) {
                        Text("Model")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        if isLoadingModels {
                            ProgressView()
                                .frame(width: 160, height: 28, alignment: .center)
                        } else {
                            Picker("", selection: $selectedModel) {
                                ForEach(availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 160)
                            .onChange(of: selectedModel) { LLMService.savePreferredModel($0) }
                        }

                        Divider()
                            .frame(height: 24)

                        Text("Download")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        TextField("Model name, e.g. gemma3:4b", text: $newModelName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)

                        Button(action: { Task { await installModel() } }) {
                            HStack(spacing: 6) {
                                if isInstallingModel {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Install")
                                }
                            }
                            .frame(width: 86)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isInstallingModel || newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        Button(action: neutralizeText) {
                            HStack(spacing: 6) {
                                if isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                    Text("Neutralize")
                                }
                            }
                            .frame(width: 122)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("l", modifiers: [.command, .option, .shift])
                        .disabled(isProcessing || originalText.isEmpty)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)

                if let modelLoadError {
                    Text(modelLoadError)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding()
            .frame(minWidth: 800, minHeight: 600)
            .font(.system(size: NSFont.systemFontSize + 1))
        }
        .onAppear {
            originalFocused = true
            Task { await loadAvailableModels() }
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

    @ViewBuilder
    private func textPanel(title: String, text: Binding<String>, isEditable: Bool, selectedRange: Binding<NSRange>? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if !isEditable {
                    Button(action: { copyText(text.wrappedValue) }) {
                        Image(systemName: didCopyOutput ? "checkmark.circle.fill" : "doc.on.doc")
                        Text("Copy")
                    }
                    .buttonStyle(.bordered)
                    .help(didCopyOutput ? "Copied" : "Copy output to clipboard")
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.textBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                if let selectedRange = selectedRange {
                    let view = SelectableTextView(text: text, selectedRange: selectedRange, isEditable: isEditable)
                        .font(.system(size: 15))
                        .padding(16)

                    if isEditable {
                        view
                            .contextMenu {
                                Button("Neutralize Selected Text") {
                                    neutralizeSelectedText()
                                }
                            }
                            .focused($originalFocused)
                    } else {
                        view
                            .contextMenu {
                                Button("Copy") {
                                    copyText(text.wrappedValue)
                                }
                            }
                    }
                } else {
                    TextEditor(text: text)
                        .font(.system(size: 15))
                        .padding(16)
                        .disabled(!isEditable)
                }
            }
            .frame(minHeight: 300)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    func neutralizeText() {
        guard !originalText.isEmpty else { return }
        isProcessing = true

        Task {
            do {
                let rewritten = try await LLMService.rewrite(text: originalText, model: selectedModel)
                await MainActor.run {
                    neutralizedText = rewritten
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

    private func neutralizeSelectedText() {
        guard !originalText.isEmpty else { return }
        guard beforeSelectedRange.length > 0,
              let range = Range(beforeSelectedRange, in: originalText)
        else {
            neutralizeText()
            return
        }

        let selectedText = String(originalText[range])
        isProcessing = true

        Task {
            do {
                let rewritten = try await LLMService.rewrite(text: selectedText, model: selectedModel)
                await MainActor.run {
                    originalText.replaceSubrange(range, with: rewritten)
                    neutralizedText = originalText
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to rewrite selection: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }

    private func loadAvailableModels() async {
        isLoadingModels = true
        modelLoadError = nil

        do {
            let models = try await LLMService.fetchAvailableModels()
            await MainActor.run {
                availableModels = models.isEmpty ? LLMService.defaultModels : models
                if !availableModels.contains(selectedModel) {
                    selectedModel = availableModels.first ?? LLMService.defaultModel
                    LLMService.savePreferredModel(selectedModel)
                }
                isLoadingModels = false
            }
        } catch {
            await MainActor.run {
                availableModels = LLMService.defaultModels
                if !availableModels.contains(selectedModel) {
                    selectedModel = availableModels.first ?? LLMService.defaultModel
                    LLMService.savePreferredModel(selectedModel)
                }
                modelLoadError = "Could not load models: \(error.localizedDescription)"
                isLoadingModels = false
            }
        }
    }

    private func installModel() async {
        let modelName = newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else { return }
        isInstallingModel = true
        modelLoadError = nil

        do {
            let output = try await LLMService.installModel(named: modelName)
            await MainActor.run {
                alertMessage = "Installed model: \(modelName)"
                newModelName = ""
            }
            await loadAvailableModels()
            await MainActor.run {
                modelLoadError = output.isEmpty ? nil : output
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to install model: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isInstallingModel = false
        }
    }

    private func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        didCopyOutput = true

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                didCopyOutput = false
            }
        }
    }
}

private struct SelectableTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize + 2)
        textView.string = text
        textView.selectedRange = selectedRange

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        if textView.selectedRange != selectedRange {
            textView.selectedRange = selectedRange
        }

        textView.isEditable = isEditable
        textView.isSelectable = true
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextView

        init(_ parent: SelectableTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.selectedRange = textView.selectedRange
        }
    }
}
