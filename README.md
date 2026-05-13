# Stylometry Sanitizer

A local-first writing utility that helps reduce obvious stylometric signals in text.

Stylometry Neutralizer rewrites text into a more neutral style by reducing emotionally loaded wording, repeated phrasing, slang, unusual punctuation, and other stylistic patterns that may make writing more identifiable.

## Usage

1. Ensure Ollama is installed and running: `ollama serve`
2. Pull a small model: `ollama pull gemma3:4b`
3. Build the app: `swift build`
4. Run the app: `swift run`
5. In the app window, type or paste text.
6. Use the right-click context menu or the Neutralize Text button to rewrite the app text.
7. For cross-app neutralization, enable Accessibility permission when prompted, then press Cmd+Option+Shift+L while focus is on any text field or editor.

## Non-Goals

This tool does not guarantee anonymity. It is designed to reduce obvious writing-style signals, not defeat forensic authorship attribution.
