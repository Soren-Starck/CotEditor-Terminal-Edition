//
//  TerminalSplitContainer.swift
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
import UniformTypeIdentifiers


/// Direction for splitting terminals.
enum TerminalSplitDirection {
    case horizontal  // Side by side
    case vertical    // Top and bottom
}


/// Drop zone within a terminal split pane.
enum TerminalDropZone {
    case left
    case right
    case top
    case bottom
    case center  // Replace/tab into this pane
}


/// A node in the terminal split tree.
/// Can either be a single terminal or a split containing two child nodes.
final class TerminalSplitNode {

    // MARK: Types

    enum Content {
        case terminal(TerminalInstance)
        case split(NSSplitView, first: TerminalSplitNode, second: TerminalSplitNode)
    }


    // MARK: Properties

    private(set) var content: Content
    weak var parent: TerminalSplitNode?
    let containerView: NSView


    // MARK: Lifecycle

    /// Creates a node containing a single terminal.
    init(terminal: TerminalInstance) {
        self.content = .terminal(terminal)
        self.containerView = NSView()
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.wantsLayer = true

        setupTerminalView(terminal)
    }


    /// Creates a split node from an existing node.
    private init(splitView: NSSplitView, first: TerminalSplitNode, second: TerminalSplitNode) {
        self.content = .split(splitView, first: first, second: second)
        self.containerView = NSView()
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.wantsLayer = true

        first.parent = self
        second.parent = self

        setupSplitView(splitView)
    }


    // MARK: Public Methods

    /// Returns the terminal if this is a terminal node.
    var terminal: TerminalInstance? {
        if case .terminal(let terminal) = content {
            return terminal
        }
        return nil
    }


    /// Returns all terminals in this node and its children.
    var allTerminals: [TerminalInstance] {
        switch content {
        case .terminal(let terminal):
            return [terminal]
        case .split(_, let first, let second):
            return first.allTerminals + second.allTerminals
        }
    }


    /// Splits this node with a new terminal.
    ///
    /// - Parameters:
    ///   - terminal: The terminal to add.
    ///   - direction: The split direction.
    ///   - position: Whether the new terminal goes first or second.
    /// - Returns: The new node containing the terminal.
    @discardableResult
    func split(with terminal: TerminalInstance, direction: TerminalSplitDirection, newTerminalFirst: Bool) -> TerminalSplitNode {
        // Create the new terminal node
        let newNode = TerminalSplitNode(terminal: terminal)

        // Create split view
        let splitView = NSSplitView()
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = (direction == .horizontal)
        splitView.dividerStyle = .thin
        splitView.wantsLayer = true

        // Store current content
        let currentContent = self.content

        // Create a node for the current content
        let currentNode: TerminalSplitNode
        switch currentContent {
        case .terminal(let existingTerminal):
            existingTerminal.terminalView.removeFromSuperview()
            currentNode = TerminalSplitNode(terminal: existingTerminal)
        case .split(let existingSplit, let first, let second):
            existingSplit.removeFromSuperview()
            currentNode = TerminalSplitNode(splitView: existingSplit, first: first, second: second)
        }

        // Set up the new split
        let firstNode = newTerminalFirst ? newNode : currentNode
        let secondNode = newTerminalFirst ? currentNode : newNode

        firstNode.parent = self
        secondNode.parent = self

        // Add views to split view
        splitView.addSubview(firstNode.containerView)
        splitView.addSubview(secondNode.containerView)

        // Update our content
        self.content = .split(splitView, first: firstNode, second: secondNode)

        // Set up the split view in our container
        setupSplitView(splitView)

        // Set equal sizes
        DispatchQueue.main.async {
            let position = splitView.isVertical
                ? splitView.bounds.size.width / 2
                : splitView.bounds.size.height / 2
            splitView.setPosition(position, ofDividerAt: 0)
        }

        return newNode
    }


    /// Removes a terminal from the split, collapsing the split if needed.
    ///
    /// - Parameter terminalID: The ID of the terminal to remove.
    /// - Returns: Whether the terminal was found and removed.
    @discardableResult
    func remove(terminalID: UUID) -> Bool {
        switch content {
        case .terminal(let terminal):
            if terminal.id == terminalID {
                terminal.terminalView.removeFromSuperview()
                // Parent will handle collapsing
                return true
            }
            return false

        case .split(let splitView, let first, let second):
            // Check if terminal is in first child
            if first.terminal?.id == terminalID {
                // Collapse: replace self with second child's content
                first.terminal?.terminalView.removeFromSuperview()
                splitView.removeFromSuperview()
                promoteChild(second)
                return true
            }

            // Check if terminal is in second child
            if second.terminal?.id == terminalID {
                // Collapse: replace self with first child's content
                second.terminal?.terminalView.removeFromSuperview()
                splitView.removeFromSuperview()
                promoteChild(first)
                return true
            }

            // Recursively search children
            if first.remove(terminalID: terminalID) {
                return true
            }
            if second.remove(terminalID: terminalID) {
                return true
            }

            return false
        }
    }


    /// Finds the node containing the specified terminal.
    func findNode(for terminalID: UUID) -> TerminalSplitNode? {
        switch content {
        case .terminal(let terminal):
            return terminal.id == terminalID ? self : nil
        case .split(_, let first, let second):
            return first.findNode(for: terminalID) ?? second.findNode(for: terminalID)
        }
    }


    // MARK: Private Methods

    private func setupTerminalView(_ terminal: TerminalInstance) {
        terminal.terminalView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(terminal.terminalView)

        NSLayoutConstraint.activate([
            terminal.terminalView.topAnchor.constraint(equalTo: containerView.topAnchor),
            terminal.terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            terminal.terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            terminal.terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }


    private func setupSplitView(_ splitView: NSSplitView) {
        for subview in containerView.subviews {
            subview.removeFromSuperview()
        }

        containerView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: containerView.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }


    /// Promotes a child node's content to this node (used when collapsing a split).
    private func promoteChild(_ child: TerminalSplitNode) {
        // Clear our container
        for subview in containerView.subviews {
            subview.removeFromSuperview()
        }

        // Take on the child's content
        switch child.content {
        case .terminal(let terminal):
            self.content = .terminal(terminal)
            setupTerminalView(terminal)

        case .split(let splitView, let first, let second):
            first.parent = self
            second.parent = self
            self.content = .split(splitView, first: first, second: second)
            setupSplitView(splitView)
        }
    }
}


/// Container view that manages split terminal layouts and provides drop zone feedback.
final class TerminalSplitContainerView: NSView {

    // MARK: Properties

    private(set) var rootNode: TerminalSplitNode?

    /// The currently active drop zone during a drag.
    var activeDropZone: TerminalDropZone?

    /// The terminal ID being dragged over.
    var dropTargetTerminalID: UUID?

    /// Callback when a drop occurs.
    var onDrop: ((UUID, TerminalDropZone, UUID?) -> Void)?

    private var dropZoneOverlay: NSView?


    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }


    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }


    private func setup() {
        wantsLayer = true
        // Register for the terminal tab UTType
        registerForDraggedTypes([NSPasteboard.PasteboardType(UTType.terminalTab.identifier)])
    }


    // MARK: Public Methods

    /// Sets up the container with an initial terminal.
    func setupWithTerminal(_ terminal: TerminalInstance) {
        // Remove existing root
        rootNode?.containerView.removeFromSuperview()

        // Create new root node
        let node = TerminalSplitNode(terminal: terminal)
        rootNode = node

        addSubview(node.containerView)

        NSLayoutConstraint.activate([
            node.containerView.topAnchor.constraint(equalTo: topAnchor),
            node.containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            node.containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            node.containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }


    /// Adds a terminal by splitting the specified target terminal.
    func addTerminal(_ terminal: TerminalInstance, relativeTo targetID: UUID?, zone: TerminalDropZone) {
        guard let rootNode else {
            setupWithTerminal(terminal)
            return
        }

        // Find the target node
        let targetNode: TerminalSplitNode
        if let targetID, let found = rootNode.findNode(for: targetID) {
            targetNode = found
        } else {
            targetNode = rootNode
        }

        // Determine split direction and position
        let direction: TerminalSplitDirection
        let newTerminalFirst: Bool

        switch zone {
        case .left:
            direction = .horizontal
            newTerminalFirst = true
        case .right:
            direction = .horizontal
            newTerminalFirst = false
        case .top:
            direction = .vertical
            newTerminalFirst = true
        case .bottom:
            direction = .vertical
            newTerminalFirst = false
        case .center:
            // For center drops, just add to the same split as the target
            direction = .horizontal
            newTerminalFirst = false
        }

        targetNode.split(with: terminal, direction: direction, newTerminalFirst: newTerminalFirst)
    }


    /// Removes a terminal from the split layout.
    func removeTerminal(id: UUID) {
        rootNode?.remove(terminalID: id)
    }


    /// Returns all terminals in the split layout.
    var allTerminals: [TerminalInstance] {
        rootNode?.allTerminals ?? []
    }


    // MARK: Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDropZone(for: sender)
        return .move
    }


    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDropZone(for: sender)
        return .move
    }


    override func draggingExited(_ sender: NSDraggingInfo?) {
        hideDropZoneOverlay()
        activeDropZone = nil
        dropTargetTerminalID = nil
    }


    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let zone = activeDropZone else {
            hideDropZoneOverlay()
            return false
        }

        // Try to read UUID from the pasteboard
        let pasteboardType = NSPasteboard.PasteboardType(UTType.terminalTab.identifier)
        var terminalID: UUID?

        if let data = sender.draggingPasteboard.data(forType: pasteboardType),
           let uuidString = String(data: data, encoding: .utf8) {
            terminalID = UUID(uuidString: uuidString)
        } else if let string = sender.draggingPasteboard.string(forType: .string),
                  let uuid = UUID(uuidString: string) {
            terminalID = uuid
        }

        guard let terminalID else {
            hideDropZoneOverlay()
            return false
        }

        onDrop?(terminalID, zone, dropTargetTerminalID)
        hideDropZoneOverlay()
        activeDropZone = nil
        dropTargetTerminalID = nil
        return true
    }


    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        hideDropZoneOverlay()
    }


    // MARK: Private Methods

    private func updateDropZone(for sender: NSDraggingInfo) {
        let location = convert(sender.draggingLocation, from: nil)

        // Find which terminal pane we're over
        if let rootNode {
            let (zone, terminalID) = determineDropZone(at: location, in: rootNode)
            activeDropZone = zone
            dropTargetTerminalID = terminalID
            showDropZoneOverlay(zone: zone, terminalID: terminalID)
        }
    }


    private func determineDropZone(at point: NSPoint, in node: TerminalSplitNode) -> (TerminalDropZone, UUID?) {
        // Convert point to the node's container coordinate space
        let localPoint = node.containerView.convert(point, from: self)
        let bounds = node.containerView.bounds

        switch node.content {
        case .terminal(let terminal):
            // Calculate zone based on position within terminal
            let relativeX = localPoint.x / bounds.width
            let relativeY = localPoint.y / bounds.height

            let edgeThreshold: CGFloat = 0.25

            if relativeX < edgeThreshold {
                return (.left, terminal.id)
            } else if relativeX > 1 - edgeThreshold {
                return (.right, terminal.id)
            } else if relativeY < edgeThreshold {
                return (.bottom, terminal.id)
            } else if relativeY > 1 - edgeThreshold {
                return (.top, terminal.id)
            } else {
                return (.center, terminal.id)
            }

        case .split(_, let first, let second):
            // Convert point to the split view coordinate space for child frame checks
            let firstLocalPoint = first.containerView.convert(point, from: self)
            let secondLocalPoint = second.containerView.convert(point, from: self)

            if first.containerView.bounds.contains(firstLocalPoint) {
                return determineDropZone(at: point, in: first)
            } else if second.containerView.bounds.contains(secondLocalPoint) {
                return determineDropZone(at: point, in: second)
            }

            // Default to root
            return (.center, nil)
        }
    }


    private func showDropZoneOverlay(zone: TerminalDropZone, terminalID: UUID?) {
        hideDropZoneOverlay()

        guard let terminalID,
              let rootNode,
              let targetNode = rootNode.findNode(for: terminalID) else {
            return
        }

        let overlay = NSView()
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
        overlay.layer?.borderColor = NSColor.controlAccentColor.cgColor
        overlay.layer?.borderWidth = 3
        overlay.layer?.cornerRadius = 8

        let containerFrame = targetNode.containerView.convert(targetNode.containerView.bounds, to: self)
        var overlayFrame: NSRect

        // Determine the icon for the drop zone
        let iconName: String
        switch zone {
        case .left:
            overlayFrame = NSRect(x: containerFrame.minX + 4,
                                  y: containerFrame.minY + 4,
                                  width: containerFrame.width / 2 - 8,
                                  height: containerFrame.height - 8)
            iconName = "rectangle.lefthalf.inset.filled"
        case .right:
            overlayFrame = NSRect(x: containerFrame.midX + 4,
                                  y: containerFrame.minY + 4,
                                  width: containerFrame.width / 2 - 8,
                                  height: containerFrame.height - 8)
            iconName = "rectangle.righthalf.inset.filled"
        case .top:
            overlayFrame = NSRect(x: containerFrame.minX + 4,
                                  y: containerFrame.midY + 4,
                                  width: containerFrame.width - 8,
                                  height: containerFrame.height / 2 - 8)
            iconName = "rectangle.tophalf.inset.filled"
        case .bottom:
            overlayFrame = NSRect(x: containerFrame.minX + 4,
                                  y: containerFrame.minY + 4,
                                  width: containerFrame.width - 8,
                                  height: containerFrame.height / 2 - 8)
            iconName = "rectangle.bottomhalf.inset.filled"
        case .center:
            overlayFrame = containerFrame.insetBy(dx: 8, dy: 8)
            iconName = "rectangle.center.inset.filled"
        }

        // Add an icon to indicate the split direction
        let iconSize: CGFloat = 32
        if let iconImage = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let iconView = NSImageView(image: iconImage)
            iconView.frame = NSRect(
                x: (overlayFrame.width - iconSize) / 2,
                y: (overlayFrame.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            iconView.contentTintColor = .white
            iconView.imageScaling = .scaleProportionallyUpOrDown
            overlay.addSubview(iconView)
        }

        overlay.frame = overlayFrame
        addSubview(overlay)
        dropZoneOverlay = overlay
    }


    private func hideDropZoneOverlay() {
        dropZoneOverlay?.removeFromSuperview()
        dropZoneOverlay = nil
    }
}


// MARK: - UTType Extension

extension UTType {
    /// UTType for terminal tab drag operations.
    static let terminalTab = UTType(exportedAs: "com.coteditor.terminal.tab.drag")
}
