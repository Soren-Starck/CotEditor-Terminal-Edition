# CotEditor Terminal Edition

A fork of [CotEditor](https://coteditor.com) with a built-in terminal.

![macOS](https://img.shields.io/badge/macOS-15.0+-blue)
![License](https://img.shields.io/badge/license-Apache%202.0-green)

## Why this fork?

CotEditor is a fantastic lightweight text editor for macOS, but I kept finding myself switching between it and Terminal.app while coding. This fork adds an integrated terminal panel so you can edit files and run commands in the same window.

## Features

Everything from the original CotEditor, plus:

- **Integrated terminal** — Toggle with `⌘\`` or View → Terminal → Show Terminal
- **Multiple tabs** — Open several terminal sessions (`⇧⌘T` to create, `⇧⌘W` to close)
- **Smart working directory** — Automatically opens at your project root (detects `.git`, `Package.swift`, `.xcodeproj`, etc.)
- **Preferences** — Customize shell, font size, and cursor style in Settings → Terminal

## Screenshot

<!-- TODO: Add screenshot -->

## Building

1. Clone the repo
2. Open `CotEditor.xcodeproj` in Xcode 16+
3. Build and run

Note: You'll need to change the bundle identifier and disable code signing for local development.

## Credits

- [CotEditor](https://github.com/coteditor/CotEditor) by 1024jp — the original editor this is based on
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza — the terminal emulator library

## License

Apache License 2.0 — same as the original CotEditor.

See [LICENSE](LICENSE) for details.
