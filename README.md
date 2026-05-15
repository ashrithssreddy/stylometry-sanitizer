# Stylometry Sanitizer

Local-first text rewriting for a smaller writing fingerprint.

Stylometry Sanitizer is a macOS utility that rewrites selected text into a more neutral style. It reduces obvious signals such as repeated phrasing, unusual punctuation, slang, emotional exaggeration, and highly personal wording.

No cloud API is required. The rewrite path runs through your local Ollama server.

```text
select text -> local model -> rewritten text
```

## Design Bias

- Local by default
- Works across apps
- No account, no telemetry, no hosted inference
- Small models supported
- Native macOS Services and Accessibility workflows

## Prerequisites

- macOS 12 or newer
- Swift 5.9 or newer
- Ollama installed locally
- At least one Ollama model installed

Install Ollama from:

```text
https://ollama.com
```

Start the local server:

```sh
ollama serve
```

Install a model:

```sh
ollama pull gemma3:4b
```

Smaller models start faster and use less memory. Larger models usually produce better rewrites.

## Build From Source

Build:

```sh
swift build
```

Open the bundled app:

```sh
open StylometrySanitizer.app
```

When rebuilding during development, copy the fresh executable into the app bundle:

```sh
cp .build/arm64-apple-macosx/debug/StylometrySanitizer \
  StylometrySanitizer.app/Contents/MacOS/StylometrySanitizer
```

## Models

The app reads locally installed models from Ollama at:

```text
http://localhost:11434/api/tags
```

The download dropdown is populated from Ollama's public model catalog when available.

If a model is not listed, install it directly:

```sh
ollama pull model-name
```

Then reopen the app so the installed model appears in the model picker.

## Rewrite Anywhere

Stylometry Sanitizer supports two system-level workflows.

`Cmd+Option+Shift+L` rewrites selected text in the focused app using Accessibility and clipboard automation. This is the most practical path for custom editors such as Sublime Text.

macOS Services can expose `Rewrite with Stylometry Sanitizer` in standard text controls, usually under `Right click > Services`. This works best in native macOS text fields, Notes, TextEdit, and browser text fields.

If the Services item does not appear, check:

```text
System Settings > Keyboard > Keyboard Shortcuts > Services > Text
```

Enable `Rewrite with Stylometry Sanitizer` if it is listed there.

## Permissions

The global shortcut needs Accessibility permission because macOS requires it for apps that copy and replace selected text in other applications.

macOS will prompt for this permission. It can also be enabled manually:

```text
System Settings > Privacy & Security > Accessibility
```

## Troubleshooting

Ollama not responding:

```sh
ollama serve
```

Selected model missing:

```sh
ollama list
```

Services item missing:

```sh
/System/Library/CoreServices/pbs -flush
```

Then quit and reopen the app.

macOS may cache Services and Dock metadata for app bundles outside `/Applications`.
