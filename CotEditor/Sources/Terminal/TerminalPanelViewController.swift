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


/// Observable state for the terminal tab bar.
@MainActor
final class TerminalTabBarState: ObservableObject {

    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabID: UUID?

    var onNewTab: (() -> Void)?
    var onCloseTab: ((UUID) -> Void)?
    var onSelectTab: ((UUID) -> Void)?
}


/// View controller managing multiple terminal instances in a bottom panel.
final class TerminalPanelViewController: NSViewController {

    // MARK: Public Properties

    /// The document's working directory, used for new terminals.
    var workingDirectory: URL?


    // MARK: Private Properties

    private var terminals: [TerminalInstance] = []
    private var cancellables: Set<AnyCancellable> = []
    private let tabBarState = TerminalTabBarState()

    private var containerView: NSView!
    private var tabBarHostingView: NSHostingView<TerminalTabBarWrapper>!
    private var terminalContainerView: NSView!


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

        // Create tab bar with observable state
        let tabBarWrapper = TerminalTabBarWrapper(state: self.tabBarState)
        self.tabBarHostingView = NSHostingView(rootView: tabBarWrapper)
        self.tabBarHostingView.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.addSubview(self.tabBarHostingView)

        // Create terminal container
        self.terminalContainerView = NSView()
        self.terminalContainerView.translatesAutoresizingMaskIntoConstraints = false
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


    override func viewDidLoad() {
        super.viewDidLoad()

        // Create initial terminal if none exists
        if self.terminals.isEmpty {
            self.createNewTerminal()
        }
    }


    override func viewWillAppear() {
        super.viewWillAppear()

        // Start process for selected terminal if not running
        if let terminal = self.selectedTerminal, !terminal.isRunning {
            terminal.startProcess()
        }
    }


    // MARK: Public Methods

    /// Creates a new terminal tab.
    @discardableResult
    func createNewTerminal() -> TerminalInstance {
        let terminal = TerminalInstance(workingDirectory: self.workingDirectory)

        // Observe title changes
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

        self.terminals.append(terminal)

        // Create tab
        let tab = TerminalTab(id: terminal.id, title: terminal.title, isRunning: terminal.isRunning)
        self.tabBarState.tabs.append(tab)

        // Select and show the new terminal
        self.selectTerminal(id: terminal.id)

        // Start the process
        terminal.startProcess()

        return terminal
    }


    /// Closes the specified terminal.
    ///
    /// - Parameter id: The ID of the terminal to close.
    func closeTerminal(id: UUID) {
        guard let index = self.terminals.firstIndex(where: { $0.id == id }) else { return }

        let terminal = self.terminals[index]
        terminal.terminateProcess()
        terminal.terminalView.removeFromSuperview()

        self.terminals.remove(at: index)
        self.tabBarState.tabs.removeAll { $0.id == id }

        // Select another terminal if the closed one was selected
        if self.tabBarState.selectedTabID == id {
            if let nextTerminal = self.terminals.first {
                self.selectTerminal(id: nextTerminal.id)
            } else {
                self.tabBarState.selectedTabID = nil
                // Create a new terminal if all were closed
                self.createNewTerminal()
            }
        }
    }


    /// Selects the specified terminal.
    ///
    /// - Parameter id: The ID of the terminal to select.
    func selectTerminal(id: UUID) {
        guard let terminal = self.terminals.first(where: { $0.id == id }) else { return }

        // Hide current terminal
        if let currentID = self.tabBarState.selectedTabID,
           let currentTerminal = self.terminals.first(where: { $0.id == currentID }) {
            currentTerminal.terminalView.removeFromSuperview()
        }

        // Show selected terminal
        self.tabBarState.selectedTabID = id

        terminal.terminalView.translatesAutoresizingMaskIntoConstraints = false
        self.terminalContainerView.addSubview(terminal.terminalView)

        NSLayoutConstraint.activate([
            terminal.terminalView.topAnchor.constraint(equalTo: self.terminalContainerView.topAnchor),
            terminal.terminalView.leadingAnchor.constraint(equalTo: self.terminalContainerView.leadingAnchor),
            terminal.terminalView.trailingAnchor.constraint(equalTo: self.terminalContainerView.trailingAnchor),
            terminal.terminalView.bottomAnchor.constraint(equalTo: self.terminalContainerView.bottomAnchor),
        ])

        // Focus the terminal
        self.view.window?.makeFirstResponder(terminal.terminalView)

        // Start process if not running
        if !terminal.isRunning {
            terminal.startProcess()
        }
    }


    /// Selects the next terminal tab.
    func selectNextTerminal() {
        guard let currentID = self.tabBarState.selectedTabID,
              let currentIndex = self.terminals.firstIndex(where: { $0.id == currentID }) else { return }

        let nextIndex = (currentIndex + 1) % self.terminals.count
        self.selectTerminal(id: self.terminals[nextIndex].id)
    }


    /// Selects the previous terminal tab.
    func selectPreviousTerminal() {
        guard let currentID = self.tabBarState.selectedTabID,
              let currentIndex = self.terminals.firstIndex(where: { $0.id == currentID }) else { return }

        let previousIndex = currentIndex == 0 ? self.terminals.count - 1 : currentIndex - 1
        self.selectTerminal(id: self.terminals[previousIndex].id)
    }


    /// Focuses the terminal.
    func focusTerminal() {
        if let terminal = self.selectedTerminal {
            self.view.window?.makeFirstResponder(terminal.terminalView)
        }
    }


    // MARK: Private Methods

    private var selectedTerminal: TerminalInstance? {
        guard let id = self.tabBarState.selectedTabID else { return nil }
        return self.terminals.first { $0.id == id }
    }


    private func updateTab(for terminal: TerminalInstance) {
        guard let index = self.tabBarState.tabs.firstIndex(where: { $0.id == terminal.id }) else { return }
        self.tabBarState.tabs[index] = TerminalTab(id: terminal.id, title: terminal.title, isRunning: terminal.isRunning)
    }
}


// MARK: - Actions

extension TerminalPanelViewController {

    @IBAction func newTerminalTab(_ sender: Any?) {
        self.createNewTerminal()
    }


    @IBAction func closeTerminalTab(_ sender: Any?) {
        guard let id = self.tabBarState.selectedTabID else { return }
        self.closeTerminal(id: id)
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
            onSelectTab: { id in state.onSelectTab?(id) }
        )
    }
}
