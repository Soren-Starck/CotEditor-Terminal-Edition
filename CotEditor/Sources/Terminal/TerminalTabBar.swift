//
//  TerminalTabBar.swift
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

import SwiftUI

/// Data model for a terminal tab.
struct TerminalTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isRunning: Bool

    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
    }
}


/// Tab bar for switching between terminal instances.
struct TerminalTabBar: View {

    @Binding var tabs: [TerminalTab]
    @Binding var selectedTabID: UUID?

    var onNewTab: () -> Void
    var onCloseTab: (UUID) -> Void
    var onSelectTab: ((UUID) -> Void)?


    var body: some View {
        HStack(spacing: 0) {
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabs) { tab in
                        TerminalTabItem(
                            tab: tab,
                            isSelected: tab.id == selectedTabID,
                            onSelect: {
                                selectedTabID = tab.id
                                onSelectTab?(tab.id)
                            },
                            onClose: { onCloseTab(tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // New tab button
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .help(String(localized: "New Terminal Tab", table: "Terminal"))
        }
        .frame(height: 26)
        .background(.bar)
    }
}


/// Individual terminal tab item.
private struct TerminalTabItem: View {

    let tab: TerminalTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false


    var body: some View {
        HStack(spacing: 4) {
            // Terminal icon
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? .primary : .secondary)

            // Title
            Text(tab.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)

            // Close button (always visible)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isHovering || isSelected ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Close Terminal Tab", table: "Terminal"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovering)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}


// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var tabs: [TerminalTab] = [
            TerminalTab(id: UUID(), title: "Terminal", isRunning: true),
            TerminalTab(id: UUID(), title: "CotEditor", isRunning: true),
            TerminalTab(id: UUID(), title: "Documents", isRunning: false),
        ]
        @State private var selectedID: UUID?

        var body: some View {
            TerminalTabBar(
                tabs: $tabs,
                selectedTabID: $selectedID,
                onNewTab: {
                    let newTab = TerminalTab(id: UUID(), title: "New Terminal", isRunning: true)
                    tabs.append(newTab)
                    selectedID = newTab.id
                },
                onCloseTab: { id in
                    tabs.removeAll { $0.id == id }
                }
            )
            .onAppear {
                selectedID = tabs.first?.id
            }
        }
    }

    return PreviewWrapper()
        .frame(width: 400)
}
