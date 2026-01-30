//
//  TerminalSettingsView.swift
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
import Defaults

struct TerminalSettingsView: View {

    @Namespace private var accessibility

    @AppStorage(.terminalShellPath) private var shellPath: String
    @AppStorage(.terminalFontSize) private var fontSize: Double
    @AppStorage(.terminalUseEditorFont) private var useEditorFont: Bool
    @AppStorage(.terminalScrollbackLines) private var scrollbackLines: Int
    @AppStorage(.terminalCursorStyle) private var cursorStyle: Int


    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 14) {
            GridRow {
                Text("Shell:", tableName: "TerminalSettings")
                    .gridColumnAlignment(.trailing)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("", text: $shellPath)
                        .frame(width: 200)
                        .accessibilityLabeledPair(role: .content, id: "shellPath", in: self.accessibility)

                    Text("Path to the shell executable (e.g., /bin/zsh, /bin/bash)", tableName: "TerminalSettings")
                        .foregroundStyle(.secondary)
                        .controlSize(.small)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GridRow {
                Text("Font:", tableName: "TerminalSettings")
                    .gridColumnAlignment(.trailing)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(String(localized: "Use editor font", table: "TerminalSettings"), isOn: $useEditorFont)

                    HStack {
                        Text("Size:", tableName: "TerminalSettings")
                            .accessibilityLabeledPair(role: .label, id: "fontSize", in: self.accessibility)

                        TextField("", value: $fontSize, format: .number)
                            .frame(width: 50)
                            .accessibilityLabeledPair(role: .content, id: "fontSize", in: self.accessibility)

                        Stepper("", value: $fontSize, in: 8...72, step: 1)
                            .labelsHidden()
                    }
                }
            }

            GridRow {
                Text("Cursor:", tableName: "TerminalSettings")
                    .gridColumnAlignment(.trailing)
                    .accessibilityLabeledPair(role: .label, id: "cursorStyle", in: self.accessibility)

                Picker(selection: $cursorStyle) {
                    ForEach(TerminalCursorStyle.allCases, id: \.rawValue) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .accessibilityLabeledPair(role: .content, id: "cursorStyle", in: self.accessibility)
            }

            GridRow {
                Text("Scrollback:", tableName: "TerminalSettings")
                    .gridColumnAlignment(.trailing)
                    .accessibilityLabeledPair(role: .label, id: "scrollback", in: self.accessibility)

                HStack {
                    TextField("", value: $scrollbackLines, format: .number)
                        .frame(width: 80)
                        .accessibilityLabeledPair(role: .content, id: "scrollback", in: self.accessibility)

                    Text("lines", tableName: "TerminalSettings")
                }
            }

            HStack {
                Spacer()
                HelpLink(anchor: "settings_terminal")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .scenePadding()
        .frame(width: 500)
    }
}


// MARK: - Preview

#Preview {
    TerminalSettingsView()
}
