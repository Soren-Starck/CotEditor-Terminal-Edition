//
//  ContentViewController.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2024-05-04.
//
//  ---------------------------------------------------------------------------
//
//  © 2024-2025 1024jp
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
import SwiftUI
import Combine
import Defaults

final class ContentViewController: NSSplitViewController {

    // MARK: Public Properties

    var document: DataDocument?  { didSet { self.updateDocument(from: oldValue) } }

    var documentViewController: DocumentViewController? {

        self.splitViewItems.first?.viewController as? DocumentViewController
    }

    /// The terminal panel view controller.
    private(set) var terminalPanelViewController: TerminalPanelViewController?


    // MARK: Private Properties

    private var terminalViewItem: NSSplitViewItem?
    private var terminalObserver: AnyCancellable?


    // MARK: Lifecycle

    init(document: DataDocument?) {

        self.document = document

        super.init(nibName: nil, bundle: nil)

        self.splitViewItems = [
            NSSplitViewItem(viewController: .viewController(document: document)),
        ]
    }


    required init?(coder: NSCoder) {

        fatalError("init(coder:) has not been implemented")
    }


    override func viewDidLoad() {

        super.viewDidLoad()

        self.splitView.isVertical = false

        // Add terminal panel
        self.setupTerminalPanel()
    }


    override func viewWillAppear() {

        super.viewWillAppear()

        // Observe user defaults for terminal visibility
        self.terminalObserver = UserDefaults.standard.publisher(for: .showTerminal)
            .sink { [weak self] show in
                self?.terminalViewItem?.animator().isCollapsed = !show
            }
    }


    override func viewDidDisappear() {

        super.viewDidDisappear()

        self.terminalObserver?.cancel()
        self.terminalObserver = nil
    }


    // MARK: Split View Controller Methods

    override func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {

        // Allow dragging for terminal divider (index 0 is document/terminal divider when terminal exists)
        // but hide the status bar divider
        if let terminalViewItem, !terminalViewItem.isCollapsed, dividerIndex == 0 {
            return proposedEffectiveRect
        }
        return .zero
    }


    // MARK: Public Methods

    /// Toggles the terminal panel visibility.
    func toggleTerminal() {
        UserDefaults.standard[.showTerminal].toggle()
    }


    /// Shows the terminal panel.
    func showTerminal() {
        UserDefaults.standard[.showTerminal] = true
        self.terminalPanelViewController?.focusTerminal()
    }


    /// Hides the terminal panel.
    func hideTerminal() {
        UserDefaults.standard[.showTerminal] = false
    }


    /// Creates a new terminal tab.
    func newTerminalTab() {
        self.showTerminal()
        self.terminalPanelViewController?.createNewTerminal()
    }


    /// Closes the current terminal tab.
    func closeTerminalTab() {
        self.terminalPanelViewController?.closeTerminalTab(nil)
    }


    // MARK: Private Methods

    private func setupTerminalPanel() {
        // Determine working directory from document (use project root)
        let workingDirectory: URL?
        if let document = self.document as? Document,
           let fileURL = document.fileURL {
            workingDirectory = Self.findProjectRoot(from: fileURL)
        } else {
            workingDirectory = nil
        }

        let terminalVC = TerminalPanelViewController(workingDirectory: workingDirectory)
        self.terminalPanelViewController = terminalVC

        let terminalItem = NSSplitViewItem(viewController: terminalVC)
        terminalItem.canCollapse = true
        terminalItem.isCollapsed = !UserDefaults.standard[.showTerminal]
        terminalItem.minimumThickness = 100
        terminalItem.holdingPriority = .defaultLow - 1

        self.terminalViewItem = terminalItem
        self.addSplitViewItem(terminalItem)
    }


    /// Finds the project root directory by looking for common project markers.
    ///
    /// - Parameter fileURL: The file URL to start searching from.
    /// - Returns: The project root URL, or the file's parent directory if no root is found.
    private static func findProjectRoot(from fileURL: URL) -> URL {
        let fileManager = FileManager.default
        var currentDir = fileURL.deletingLastPathComponent()
        let homeDir = fileManager.homeDirectoryForCurrentUser

        // Project markers to look for (in order of priority)
        let projectMarkers = [
            ".git",
            "Package.swift",      // Swift Package
            ".xcodeproj",         // Xcode project
            ".xcworkspace",       // Xcode workspace
            "Cargo.toml",         // Rust
            "package.json",       // Node.js
            "pyproject.toml",     // Python
            "Makefile",
            "CMakeLists.txt",
        ]

        // Walk up the directory tree
        while currentDir.path != "/" && currentDir.path != homeDir.path {
            for marker in projectMarkers {
                // Check for exact match or directory starting with marker (for .xcodeproj)
                if marker.hasSuffix("proj") || marker.hasSuffix("workspace") {
                    // Look for directories ending with this suffix
                    if let contents = try? fileManager.contentsOfDirectory(at: currentDir, includingPropertiesForKeys: nil),
                       contents.contains(where: { $0.lastPathComponent.hasSuffix(marker) }) {
                        return currentDir
                    }
                } else {
                    let markerURL = currentDir.appendingPathComponent(marker)
                    if fileManager.fileExists(atPath: markerURL.path) {
                        return currentDir
                    }
                }
            }
            currentDir = currentDir.deletingLastPathComponent()
        }

        // No project root found, return the file's parent directory
        return fileURL.deletingLastPathComponent()
    }


    /// Updates the document in children.
    private func updateDocument(from oldDocument: DataDocument?) {

        guard oldDocument != self.document else { return }

        self.splitViewItems[0] = NSSplitViewItem(viewController: .viewController(document: self.document))

        // Update terminal working directory to project root
        if let document = self.document as? Document,
           let fileURL = document.fileURL {
            self.terminalPanelViewController?.workingDirectory = Self.findProjectRoot(from: fileURL)
        }
    }
}


private extension NSViewController {
    
    /// Creates a new view controller with the passed-in document.
    ///
    /// - Parameter document: The represented document.
    /// - Returns: A view controller.
    static func viewController(document: DataDocument?) -> sending NSViewController {
        
        switch document {
            case let document as Document:
                DocumentViewController(document: document)
            case let document as PreviewDocument:
                NSHostingController(rootView: FilePreviewView(item: document))
            case .none:
                NSHostingController(rootView: NoDocumentView())
            default:
                preconditionFailure()
        }
    }
}
