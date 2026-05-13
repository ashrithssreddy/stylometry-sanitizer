import SwiftUI

struct ContentView: View {
    @State private var originalText = "Type or paste your text here. Press Neutralize to see the before and after text."
    @State private var neutralizedText = ""
    @State private var selectedModel = LLMService.preferredModel()
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = true
    @State private var modelLoadError: String?
    @State private var isProcessing = false
    @State private var alertMessage: String?
    @FocusState private var originalFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Stylometry Sanitizer")
                .font(.title2)
                .bold()

            Text("Compare the original text with the neutralized result.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 16) {
                textPanel(title: "Before", text: $originalText, isEditable: true)
                textPanel(title: "After", text: $neutralizedText, isEditable: false)
            }
            .frame(minHeight: 340)

            HStack(spacing: 12) {
                if isLoadingModels {
                    ProgressView()
                        .frame(width: 120)
                }

                Picker("Model:", selection: $selectedModel) {
                    ForEach(availableModels, id: \ .self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 180)
                .disabled(isLoadingModels || availableModels.isEmpty)
                .onChange(of: selectedModel) { LLMService.savePreferredModel($0) }

                Button(action: neutralizeText) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("Neutralize")
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .option, .shift])
                .disabled(isProcessing || originalText.isEmpty)

                Button("Reload Models") {
                    Task { await loadAvailableModels() }
                }
                .disabled(isLoadingModels)

                Spacer()

                Text("Right-click in the before panel to neutralize selected text in place.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if let modelLoadError {
                Text(modelLoadError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(minWidth: 740, minHeight: 520)
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
    private func textPanel(title: String, text: Binding<String>, isEditable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            TextEditor(text: text)
                .font(.system(.body, design: .default))
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .disabled(!isEditable)
                .contextMenu {
                    if title == "Before" {
                        Button("Neutralize Text") {
                            neutralizeText()
                        }
                    }
                }
                .focused($originalFocused)
        }
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
}
