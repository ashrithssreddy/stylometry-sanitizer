# Stylometry Sanitizer

A local-first macOS writing utility for reducing obvious stylometric signals in text.

Stylometry Sanitizer rewrites text into a more neutral style by reducing emotionally loaded wording, repeated phrasing, slang, unusual punctuation, and other distinctive writing patterns. Rewriting is handled locally through Ollama.

## Prerequisites

- macOS 12 or newer
- Swift 5.9 or newer
- Ollama installed locally
- At least one Ollama model installed

Install Ollama from `https://ollama.com`, then start the local server:

```sh
ollama serve
```

In another terminal, install a model:

```sh
ollama pull gemma3:4b
```

Smaller models start faster and use less memory. Larger models usually produce better rewrites.

## Build

Build the executable:

```sh
swift build
```

This repository also includes a root app bundle:

```sh
open StylometrySanitizer.app
```

When rebuilding during development, copy the fresh executable into the app bundle:

```sh
cp .build/arm64-apple-macosx/debug/StylometrySanitizer \
  StylometrySanitizer.app/Contents/MacOS/StylometrySanitizer
```

## Model Management

The app reads locally installed models from Ollama at:

```text
http://localhost:11434/api/tags
```

The download dropdown is populated from Ollama's public model catalog when available. If a model is not listed, install it manually:

```sh
ollama pull model-name
```

Then reopen the app so the installed model appears in the model picker.

## Cross-App Rewriting

Stylometry Sanitizer supports two system-level workflows.

`Cmd+Option+Shift+L` rewrites the selected text in the focused app using Accessibility and clipboard automation. This is the most practical path for custom editors such as Sublime Text.

macOS Services can expose `Rewrite with Stylometry Sanitizer` in standard text controls, usually under `Right click > Services`. This works best in apps that use native macOS text fields, such as Notes, TextEdit, and browser text fields.

If the Services item does not appear, check:

```text
System Settings > Keyboard > Keyboard Shortcuts > Services > Text
```

Enable `Rewrite with Stylometry Sanitizer` if it is listed there.

## Permissions

The global shortcut workflow requires Accessibility permission because the app needs to copy and replace selected text in other apps.

macOS will prompt for this permission. It can also be enabled manually:

```text
System Settings > Privacy & Security > Accessibility
```

## Troubleshooting

If model loading fails, confirm Ollama is running:

```sh
ollama serve
```

If rewriting fails with a model error, confirm the selected model is installed:

```sh
ollama list
```

If the app icon or Services item does not refresh, quit and reopen the app. macOS may also cache Services and Dock metadata for app bundles outside `/Applications`.

## Non-Goals

This tool does not guarantee anonymity. It is designed to reduce obvious writing-style signals, not defeat forensic authorship attribution.
