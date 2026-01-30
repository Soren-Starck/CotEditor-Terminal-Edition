//
//  TerminalPanelViewController.swift
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
import SwiftUI
import Combine
import Defaults


/// Observable state for the terminal tab bar.
@MainActor
final class TerminalTabBarState: ObservableObject {

    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabID: UUID?

    var onNewTab: (() -> Void)?
    var onCloseTab: ((UUID) -> Void)?
    var onSelectTab: ((UUID) -> Void)?
    var onCollapse: (() -> Void)?
}


/// View controller managing multiple terminal instances in a bottom panel.
/// Supports both tabs and split views for terminals.
final class TerminalPanelViewController: NSViewController {

    // MARK: Public Properties

    /// The document's working directory, used for new terminals.
    var workingDirectory: URL?


    // MARK: Private Properties

    /// All terminal instances (both tabbed and split).
    private var terminals: [TerminalInstance] = []

    /// Mapping of terminal IDs to their split group (nil = in main tab area).
    private var terminalSplitGroups: [UUID: UUID] = [:]

    /// The split container for the currently selected tab group.
    private var splitContainers: [UUID: TerminalSplitContainerView] = [:]

    private var cancellables: Set<AnyCancellable> = []
    private let tabBarState = TerminalTabBarState()

    private var containerView: NSView!
    private var tabBarHostingView: NSHostingView<TerminalTabBarWrapper>!
    private var terminalContainerView: NSView!

    /// Currently visible split container.
    private var currentSplitContainer: TerminalSplitContainerView?


    // MARK: Lifecycle

    init(workingDirectory: URL? = nil) {
        self.workingDirectory = workingDirectory
        super.init(nibName: nil, bundle: nil)
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func loadView() {
        self.containerView = NSView()
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.wantsLayer = true
        self.view = self.containerView

        // Configure tab bar state callbacks
        self.tabBarState.onNewTab = { [weak self] in
            self?.createNewTerminal()
        }
        self.tabBarState.onCloseTab = { [weak self] id in
            self?.closeTerminal(id: id)
        }
        self.tabBarState.onSelectTab = { [weak self] id in
            self?.selectTerminal(id: id)
        }
        self.tabBarState.onCollapse = {
            UserDefaults.standard[.showTerminal] = false
        }

        // Create tab bar with observable state
        let tabBarWrapper = TerminalTabBarWrapper(state: self.tabBarState)
        self.tabBarHostingView = NSHostingView(rootView: tabBarWrapper)
        self.tabBarHostingView.translatesAutoresizingMaskIntoConstraints = false
        // Ensure the hosting view uses the exact height we specify
        self.tabBarHostingView.setContentHuggingPriority(.required, for: .vertical)
        self.tabBarHostingView.setContentCompressionResistancePriority(.required, for: .vertical)
        self.containerView.addSubview(self.tabBarHostingView)

        // Create terminal container
        self.terminalContainerView = NSView()
        self.terminalContainerView.translatesAutoresizingMaskIntoConstraints = false
        self.terminalContainerView.wantsLayer = true
        self.containerView.addSubview(self.terminalContainerView)

        // Layout constraints
        NSLayoutConstraint.activate([
            self.tabBarHostingView.topAnchor.constraint(equalTo: self.containerView.topAnchor),
            self.tabBarHostingView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            self.tabBarHostingView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
            self.tabBarHostingView.heightAnchor.constraint(equalToConstant: 26),

            self.terminalContainerView.topAnchor.constraint(equalTo: self.tabBarHostingView.bottomAnchor),
            self.terminalContainerView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            self.terminalContainerView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
            self.terminalContainerView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor),
        ])
    }


    override func viewDidLayout() {
        super.viewDidLayout()

        // Ensure the split container fills the terminal container
        currentSplitContainer?.frame = terminalContainerView.bounds
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        // Create initial terminal if none exists
        if self.terminals.isEmpty {
            self.createNewTerminal()
        }
    }


    override func viewWillAppear() {
        super.viewWillAppear()

        // Start process for terminals in current split container
        currentSplitContainer?.allTerminals.forEach { terminal in
            if !terminal.isRunning {
                terminal.startProcess()
            }
        }
    }


    // MARK: Public Methods

    /// Creates a new terminal tab.
    @discardableResult
    func createNewTerminal() -> TerminalInstance {
        let terminal = TerminalInstance(workingDirectory: self.workingDirectory)
        setupTerminalObservers(terminal)

        self.terminals.append(terminal)

        // Create tab
        let tab = TerminalTab(id: terminal.id, title: terminal.title, isRunning: terminal.isRunning)
        self.tabBarState.tabs.append(tab)

        // Create a new split container for this tab
        let splitContainer = createSplitContainer()
        splitContainer.setupWithTerminal(terminal)
        splitContainers[terminal.id] = splitContainer

        // Select and show the new terminal
        self.selectTerminal(id: terminal.id)

        // Start the process
        terminal.startProcess()

        return terminal
    }


    /// Creates a new terminal and splits it with the target terminal.
    ///
    /// - Parameters:
    ///   - targetID: The ID of the terminal to split with.
    ///   - zone: The drop zone indicating split direction.
    @discardableResult
    func createTerminalSplit(targetID: UUID, zone: TerminalDropZone) -> TerminalInstance? {
        guard let targetTerminal = terminals.first(where: { $0.id == targetID }) else {
            return nil
        }

        // Find the tab that contains this terminal
        let tabID = findTabID(for: targetID)
        guard let splitContainer = splitContainers[tabID] else {
            return nil
        }

        // Create new terminal
        let terminal = TerminalInstance(workingDirectory: self.workingDirectory)
        setupTerminalObservers(terminal)
        terminals.append(terminal)

        // Add to split container
        splitContainer.addTerminal(terminal, relativeTo: targetID, zone: zone)

        // Start the process
        terminal.startProcess()

        // Focus the new terminal
        self.view.window?.makeFirstResponder(terminal.terminalView)

        return terminal
    }


    /// Closes the specified terminal.
    ///
    /// - Parameter id: The ID of the terminal to close.
    func closeTerminal(id: UUID) {
        guard let index = self.terminals.firstIndex(where: { $0.id == id }) else { return }

        let terminal = self.terminals[index]
        let tabID = findTabID(for: id)

        terminal.terminateProcess()
        terminal.terminalView.removeFromSuperview()

        self.terminals.remove(at: index)

        // Check if this was a tab's primary terminal
        if let splitContainer = splitContainers[id] {
            // This was a tab - remove the whole tab
            splitContainer.removeFromSuperview()
            splitContainers.removeValue(forKey: id)
            self.tabBarState.tabs.removeAll { $0.id == id }

            // Select another terminal if needed
            if self.tabBarState.selectedTabID == id {
                if let nextTab = self.tabBarState.tabs.first {
                    self.selectTerminal(id: nextTab.id)
                } else {
                    self.tabBarState.selectedTabID = nil
                    self.createNewTerminal()
                }
            }
        } else if let splitContainer = splitContainers[tabID] {
            // This was a split terminal within a tab
            splitContainer.removeTerminal(id: id)

            // Check if the split container still has terminals
            if splitContainer.allTerminals.isEmpty {
                // Remove the empty tab
                splitContainer.removeFromSuperview()
                splitContainers.removeValue(forKey: tabID)
                self.tabBarState.tabs.removeAll { $0.id == tabID }

                if self.tabBarState.selectedTabID == tabID {
                    if let nextTab = self.tabBarState.tabs.first {
                        self.selectTerminal(id: nextTab.id)
                    } else {
                        self.createNewTerminal()
                    }
                }
            } else {
                // Focus another terminal in the same split
                if let firstTerminal = splitContainer.allTerminals.first {
                    self.view.window?.makeFirstResponder(firstTerminal.terminalView)
                }
            }
        }
    }


    /// Selects the specified terminal (by tab).
    ///
    /// - Parameter id: The ID of the terminal/tab to select.
    func selectTerminal(id: UUID) {
        let tabID = findTabID(for: id)

        guard let splitContainer = splitContainers[tabID] else { return }

        // Hide current split container
        currentSplitContainer?.removeFromSuperview()

        // Show selected split container
        self.tabBarState.selectedTabID = tabID
        self.currentSplitContainer = splitContainer

        splitContainer.translatesAutoresizingMaskIntoConstraints = false
        self.terminalContainerView.addSubview(splitContainer)

        NSLayoutConstraint.activate([
            splitContainer.topAnchor.constraint(equalTo: self.terminalContainerView.topAnchor),
            splitContainer.leadingAnchor.constraint(equalTo: self.terminalContainerView.leadingAnchor),
            splitContainer.trailingAnchor.constraint(equalTo: self.terminalContainerView.trailingAnchor),
            splitContainer.bottomAnchor.constraint(equalTo: self.terminalContainerView.bottomAnchor),
        ])

        splitContainer.frame = self.terminalContainerView.bounds
        self.terminalContainerView.layoutSubtreeIfNeeded()

        // Focus the first terminal in the split
        if let terminal = splitContainer.allTerminals.first(where: { $0.id == id }) ?? splitContainer.allTerminals.first {
            self.view.window?.makeFirstResponder(terminal.terminalView)

            // Start process if not running
            if !terminal.isRunning {
                terminal.startProcess()
            }
        }
    }


    /// Selects the next terminal tab.
    func selectNextTerminal() {
        guard let currentID = self.tabBarState.selectedTabID,
              let currentIndex = self.tabBarState.tabs.firstIndex(where: { $0.id == currentID }) else { return }

        let nextIndex = (currentIndex + 1) % self.tabBarState.tabs.count
        self.selectTerminal(id: self.tabBarState.tabs[nextIndex].id)
    }


    /// Selects the previous terminal tab.
    func selectPreviousTerminal() {
        guard let currentID = self.tabBarState.selectedTabID,
              let currentIndex = self.tabBarState.tabs.firstIndex(where: { $0.id == currentID }) else { return }

        let previousIndex = currentIndex == 0 ? self.tabBarState.tabs.count - 1 : currentIndex - 1
        self.selectTerminal(id: self.tabBarState.tabs[previousIndex].id)
    }


    /// Focuses the terminal.
    func focusTerminal() {
        if let terminal = currentSplitContainer?.allTerminals.first {
            self.view.window?.makeFirstResponder(terminal.terminalView)
        }
    }


    /// Splits the current terminal horizontally.
    func splitHorizontally() {
        guard let currentTerminal = getCurrentFocusedTerminal() else { return }
        createTerminalSplit(targetID: currentTerminal.id, zone: .right)
    }


    /// Splits the current terminal vertically.
    func splitVertically() {
        guard let currentTerminal = getCurrentFocusedTerminal() else { return }
        createTerminalSplit(targetID: currentTerminal.id, zone: .bottom)
    }


    /// Updates the working directory and changes to it in running terminals.
    ///
    /// - Parameter directory: The new working directory.
    func updateWorkingDirectory(_ directory: URL) {
        self.workingDirectory = directory

        // Change directory in all running terminals
        for terminal in terminals where terminal.isRunning {
            terminal.changeDirectory(to: directory)
        }
    }


    // MARK: Private Methods

    private func setupTerminalObservers(_ terminal: TerminalInstance) {
        terminal.$title
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak terminal] title in
                guard let terminal else { return }
                self?.updateTab(for: terminal)
            }
            .store(in: &self.cancellables)

        terminal.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak terminal] _ in
                guard let terminal else { return }
                self?.updateTab(for: terminal)
            }
            .store(in: &self.cancellables)
    }


    private func createSplitContainer() -> TerminalSplitContainerView {
        let container = TerminalSplitContainerView()
        container.translatesAutoresizingMaskIntoConstraints = false

        container.onDrop = { [weak self] draggedTerminalID, zone, targetTerminalID in
            self?.handleTerminalDrop(
                draggedTerminalID: draggedTerminalID,
                zone: zone,
                targetTerminalID: targetTerminalID
            )
        }

        return container
    }


    private func handleTerminalDrop(draggedTerminalID: UUID, zone: TerminalDropZone, targetTerminalID: UUID?) {
        // Find the terminal being dragged
        guard let draggedTerminal = terminals.first(where: { $0.id == draggedTerminalID }) else {
            return
        }

        let sourceTabID = findTabID(for: draggedTerminalID)
        let targetTabID: UUID
        if let targetID = targetTerminalID {
            targetTabID = findTabID(for: targetID)
        } else if let selectedID = tabBarState.selectedTabID {
            targetTabID = selectedID
        } else {
            return
        }

        // If dragging to the same position in the same tab, ignore
        if sourceTabID == targetTabID && targetTerminalID == draggedTerminalID && zone == .center {
            return
        }

        guard let targetContainer = splitContainers[targetTabID] else { return }

        // Remove from source
        if let sourceContainer = splitContainers[sourceTabID] {
            if sourceTabID == draggedTerminalID {
                // The dragged terminal IS the tab - we need to handle this differently
                // Just add to target without removing the source tab yet

                // Don't allow dropping a tab onto itself
                if targetTabID == sourceTabID {
                    return
                }

                // Remove the old tab's split container view but keep it in memory temporarily
                sourceContainer.removeFromSuperview()

                // Add terminal to target
                targetContainer.addTerminal(draggedTerminal, relativeTo: targetTerminalID, zone: zone)

                // Clean up the old tab
                splitContainers.removeValue(forKey: sourceTabID)
                tabBarState.tabs.removeAll { $0.id == sourceTabID }

                // Select the target tab
                selectTerminal(id: targetTabID)
            } else {
                // Remove terminal from its current split
                sourceContainer.removeTerminal(id: draggedTerminalID)

                // Add to target
                targetContainer.addTerminal(draggedTerminal, relativeTo: targetTerminalID, zone: zone)

                // Check if source container is now empty
                if sourceContainer.allTerminals.isEmpty {
                    sourceContainer.removeFromSuperview()
                    splitContainers.removeValue(forKey: sourceTabID)
                    tabBarState.tabs.removeAll { $0.id == sourceTabID }
                }
            }
        }

        // Focus the dragged terminal
        view.window?.makeFirstResponder(draggedTerminal.terminalView)
    }


    /// Finds the tab ID that contains the given terminal.
    private func findTabID(for terminalID: UUID) -> UUID {
        // Check if the terminal ID is itself a tab
        if splitContainers[terminalID] != nil {
            return terminalID
        }

        // Search through split containers
        for (tabID, container) in splitContainers {
            if container.allTerminals.contains(where: { $0.id == terminalID }) {
                return tabID
            }
        }

        // Default to the terminal ID itself
        return terminalID
    }


    /// Gets the currently focused terminal.
    private func getCurrentFocusedTerminal() -> TerminalInstance? {
        guard let firstResponder = view.window?.firstResponder else {
            return currentSplitContainer?.allTerminals.first
        }

        // Check if the first responder is one of our terminal views
        for terminal in terminals {
            if terminal.terminalView === firstResponder || terminal.terminalView.isDescendant(of: firstResponder as? NSView ?? NSView()) {
                return terminal
            }
            // Also check if first responder is descendant of terminal view
            if let responderView = firstResponder as? NSView,
               responderView.isDescendant(of: terminal.terminalView) {
                return terminal
            }
        }

        return currentSplitContainer?.allTerminals.first
    }


    private func updateTab(for terminal: TerminalInstance) {
        let tabID = findTabID(for: terminal.id)

        // Only update the tab title if the terminal IS the tab (not a split terminal)
        if tabID == terminal.id {
            guard let index = self.tabBarState.tabs.firstIndex(where: { $0.id == terminal.id }) else { return }
            self.tabBarState.tabs[index] = TerminalTab(id: terminal.id, title: terminal.title, isRunning: terminal.isRunning)
        }
    }
}


// MARK: - Actions

extension TerminalPanelViewController {

    @IBAction func newTerminalTab(_ sender: Any?) {
        self.createNewTerminal()
    }


    @IBAction func closeTerminalTab(_ sender: Any?) {
        // Close the currently focused terminal (or the tab if only one terminal)
        if let focusedTerminal = getCurrentFocusedTerminal() {
            self.closeTerminal(id: focusedTerminal.id)
        } else if let id = self.tabBarState.selectedTabID {
            self.closeTerminal(id: id)
        }
    }


    @IBAction func splitTerminalHorizontally(_ sender: Any?) {
        splitHorizontally()
    }


    @IBAction func splitTerminalVertically(_ sender: Any?) {
        splitVertically()
    }
}


// MARK: - SwiftUI Wrapper

/// Wrapper view that observes the tab bar state.
private struct TerminalTabBarWrapper: View {

    @ObservedObject var state: TerminalTabBarState

    var body: some View {
        TerminalTabBar(
            tabs: $state.tabs,
            selectedTabID: $state.selectedTabID,
            onNewTab: { state.onNewTab?() },
            onCloseTab: { id in state.onCloseTab?(id) },
            onSelectTab: { id in state.onSelectTab?(id) },
            onCollapse: state.onCollapse
        )
    }
}
