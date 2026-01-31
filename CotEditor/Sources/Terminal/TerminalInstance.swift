//
//  TerminalInstance.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created for CotEditor terminal support.
//
//  ---------------------------------------------------------------------------
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AppKit
import SwiftTerm
import Combine
import Defaults

/// Represents a single terminal session.
@MainActor
final class TerminalInstance: NSObject, Identifiable {

    // MARK: Public Properties

    let id = UUID()

    /// The terminal view.
    let terminalView: LocalProcessTerminalView

    /// The title of the terminal (based on working directory or process).
    @Published private(set) var title: String = "Terminal"

    /// Whether the terminal process is running.
    @Published private(set) var isRunning: Bool = false


    // MARK: Private Properties

    private var shellPath: String
    private var workingDirectory: URL?
    private var themeProvider: TerminalThemeProvider
    private var appearanceObserver: NSKeyValueObservation?
    private var defaultsObservers: Set<AnyCancellable> = []


    // MARK: Lifecycle

    /// Creates a new terminal instance.
    ///
    /// - Parameters:
    ///   - workingDirectory: The initial working directory for the shell.
    ///   - shellPath: The path to the shell executable.
    init(workingDirectory: URL? = nil, shellPath: String? = nil) {
        self.workingDirectory = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        self.shellPath = shellPath ?? UserDefaults.standard[.terminalShellPath]
        self.themeProvider = TerminalThemeProvider()

        self.terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))

        super.init()

        self.setupTerminal()
        self.observeDefaults()
        self.observeAppearance()
    }


    deinit {
        self.appearanceObserver?.invalidate()
    }


    // MARK: Public Methods

    /// Starts the shell process.
    func startProcess() {
        guard !self.isRunning else { return }

        let shell = self.shellPath

        // Build environment
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"

        // Set initial working directory via PWD environment variable
        if let directory = self.workingDirectory {
            environment["PWD"] = directory.path
        }

        // Start the process
        self.terminalView.startProcess(
            executable: shell,
            args: ["-l"],
            environment: Array(environment.map { "\($0.key)=\($0.value)" }),
            execName: "-" + (shell as NSString).lastPathComponent
        )

        // Change to working directory after shell starts
        if let directory = self.workingDirectory {
            // Small delay to let the shell initialize, then cd and clear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                let cdCommand = "cd \(Self.shellEscape(directory.path)) && clear\n"
                self?.terminalView.send(txt: cdCommand)
            }
        }

        self.isRunning = true
        self.updateTitle()
    }


    /// Terminates the shell process.
    func terminateProcess() {
        // SwiftTerm doesn't have a direct terminate method,
        // but the process will be cleaned up when the view is deallocated
        self.isRunning = false
    }


    /// Sends text to the terminal.
    ///
    /// - Parameter text: The text to send.
    func send(text: String) {
        self.terminalView.send(txt: text)
    }


    /// Changes the terminal's working directory.
    ///
    /// - Parameter directory: The new working directory.
    func changeDirectory(to directory: URL) {
        self.workingDirectory = directory
        self.updateTitle()
        guard self.isRunning else { return }
        let cdCommand = "cd \(Self.shellEscape(directory.path)) && clear\n"
        self.terminalView.send(txt: cdCommand)
    }


    /// Updates the terminal font.
    func updateFont() {
        let fontSize = UserDefaults.standard[.terminalFontSize]
        let useEditorFont = UserDefaults.standard[.terminalUseEditorFont]

        let font: NSFont
        if useEditorFont, let editorFontData = UserDefaults.standard[.monospacedFont],
           let editorFont = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSFont.self, from: editorFontData) {
            font = NSFont(descriptor: editorFont.fontDescriptor, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        } else {
            font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }

        self.terminalView.font = font
    }


    /// Updates the terminal colors based on appearance.
    func updateColors() {
        self.themeProvider.updateColors(for: self.terminalView.effectiveAppearance)
        self.applyColors()
    }


    // MARK: Private Methods

    private func setupTerminal() {
        self.terminalView.processDelegate = self
        self.terminalView.translatesAutoresizingMaskIntoConstraints = false

        // Ensure the terminal view uses a layer for proper rendering
        self.terminalView.wantsLayer = true

        // Configure terminal options
        let scrollback = UserDefaults.standard[.terminalScrollbackLines]
        // Note: SwiftTerm handles scrollback internally

        // Apply font
        self.updateFont()

        // Apply colors
        self.updateColors()

        // Apply cursor style
        self.updateCursorStyle()

        // Set content hugging to allow the terminal to fill available space
        self.terminalView.setContentHuggingPriority(.defaultLow, for: .vertical)
        self.terminalView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }


    private func observeDefaults() {
        UserDefaults.standard.publisher(for: .terminalFontSize)
            .sink { [weak self] _ in self?.updateFont() }
            .store(in: &self.defaultsObservers)

        UserDefaults.standard.publisher(for: .terminalUseEditorFont)
            .sink { [weak self] _ in self?.updateFont() }
            .store(in: &self.defaultsObservers)

        UserDefaults.standard.publisher(for: .terminalCursorStyle)
            .sink { [weak self] _ in self?.updateCursorStyle() }
            .store(in: &self.defaultsObservers)
    }


    private func observeAppearance() {
        self.appearanceObserver = self.terminalView.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateColors()
            }
        }
    }


    private func applyColors() {
        let colors = self.themeProvider.colors

        self.terminalView.nativeForegroundColor = colors.foregroundColor.nsColor
        self.terminalView.nativeBackgroundColor = colors.backgroundColor.nsColor
        self.terminalView.caretColor = colors.cursorColor.nsColor
        self.terminalView.selectedTextBackgroundColor = colors.selectionColor.nsColor

        // Apply ANSI colors using SwiftTerm's Color type
        if !colors.ansiColors.isEmpty {
            let swiftTermColors = colors.ansiColors.map { $0.swiftTermColor }
            self.terminalView.installColors(swiftTermColors)
        }
    }


    private func updateCursorStyle() {
        let style = TerminalCursorStyle(rawValue: UserDefaults.standard[.terminalCursorStyle]) ?? .block
        let terminal = self.terminalView.getTerminal()
        switch style {
        case .block:
            terminal.setCursorStyle(.blinkBlock)
        case .underline:
            terminal.setCursorStyle(.blinkUnderline)
        case .bar:
            terminal.setCursorStyle(.blinkBar)
        }
    }


    private func updateTitle() {
        if let directory = self.workingDirectory {
            self.title = directory.lastPathComponent
        } else {
            self.title = "Terminal"
        }
    }


    /// Escapes a path for use in shell commands.
    private static func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}


// MARK: - LocalProcessTerminalViewDelegate

extension TerminalInstance: LocalProcessTerminalViewDelegate {

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // Terminal size changed
    }


    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor in
            if !title.isEmpty {
                self.title = title
            }
        }
    }


    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        Task { @MainActor in
            if let directory {
                self.workingDirectory = URL(fileURLWithPath: directory)
                self.updateTitle()
            }
        }
    }


    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.isRunning = false
            self.title = "Terminal (ended)"
        }
    }
}
