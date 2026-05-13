# Stylometry Sanitizer

A local-first writing utility that helps reduce obvious stylometric signals in text.

Stylometry Neutralizer rewrites text into a more neutral style by reducing emotionally loaded wording, repeated phrasing, slang, unusual punctuation, and other stylistic patterns that may make writing more identifiable.

## Usage

1. Ensure Ollama is installed and running: `ollama serve`
2. Pull a small model: `ollama pull gemma3:4b`
3. Build the app: `swift build`
4. Run the app: `swift run`
5. In the app window, type or paste text.
6. Highlight the text you want to neutralize.
7. Press Cmd+Shift+N to rewrite the selected text in a neutral tone.

## Non-Goals

This tool does not guarantee anonymity. It is designed to reduce obvious writing-style signals, not defeat forensic authorship attribution.
