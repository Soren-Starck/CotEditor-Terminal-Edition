# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CotEditor Terminal Edition is a fork of [CotEditor](https://github.com/coteditor/CotEditor), a lightweight plain-text editor for macOS. This fork adds an integrated terminal panel with support for multiple tabs and split views.

## Key Terminal Features

- **Integrated Terminal Panel**: Toggle with View → Terminal or keyboard shortcut
- **Multiple Terminal Tabs**: Create new tabs, close tabs, switch between them
- **Split Terminals**: Split horizontally or vertically, drag tabs to rearrange
- **Terminal Pane Headers**: When split, each terminal shows a numbered header for identification
- **Project Root Detection**: Terminal automatically opens in the project root directory

## Architecture

### Terminal Components (in `CotEditor/Sources/Terminal/`)

- **TerminalPanelViewController.swift**: Main controller managing terminal tabs and split containers
- **TerminalInstance.swift**: Individual terminal session using SwiftTerm
- **TerminalSplitContainer.swift**: Manages split terminal layouts with drag-drop support
- **TerminalTabBar.swift**: SwiftUI tab bar for terminal tabs
- **TerminalThemeProvider.swift**: Handles terminal colors matching the editor theme
- **TerminalSettings.swift**: User defaults keys for terminal preferences

### Integration Points

- **ContentViewController.swift**: Hosts the terminal panel below the document view
- **DocumentWindowController.swift**: Window-level terminal commands
- **MainMenu.xib**: Terminal menu items

## Build & Install

### Prerequisites

- Xcode 15+ with macOS SDK
- macOS 14.0+ target

### Build Release Version

```bash
cd /Users/sorenstarck/Documents/dev/CotEditor

# Clean and build release
rm -rf build
xcodebuild -scheme CotEditor -configuration Release -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

### Install to Applications

```bash
# Copy to Applications
cp -R build/Build/Products/Release/CotEditor.app /Applications/

# Clear extended attributes (needed if on iCloud Drive)
xattr -cr /Applications/CotEditor.app

# Sign ad-hoc for local use
codesign --force --deep --sign - /Applications/CotEditor.app
```

### Quick Update Script

After pulling new changes:

```bash
git pull fork main
rm -rf build
xcodebuild -scheme CotEditor -configuration Release -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
cp -R build/Build/Products/Release/CotEditor.app /Applications/
xattr -cr /Applications/CotEditor.app
codesign --force --deep --sign - /Applications/CotEditor.app
```

## Git Remotes

- `origin`: https://github.com/coteditor/CotEditor.git (upstream)
- `fork`: https://github.com/Soren-Starck/CotEditor-Terminal-Edition.git (this fork)

Push changes to `fork`, not `origin`.

## Common Development Tasks

### Adding Terminal Features

1. Terminal settings are in `TerminalSettings.swift` with `@Default` property wrappers
2. Menu items go in `MainMenu.xib` with actions in `DocumentWindowController`
3. Split/tab logic is in `TerminalPanelViewController` and `TerminalSplitContainer`

### Testing Terminal Changes

Build debug version and run:
```bash
xcodebuild -scheme CotEditor -configuration Debug build
```

Or open `CotEditor.xcodeproj` in Xcode and run (Cmd+R).
