//
//  TerminalThemeProvider.swift
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

/// Provides terminal colors based on CotEditor theme.
@MainActor
final class TerminalThemeProvider {

    // MARK: Public Properties

    /// The current terminal colors.
    private(set) var colors: TerminalColors


    // MARK: Lifecycle

    init() {
        self.colors = Self.defaultColors()
    }


    // MARK: Public Methods

    /// Updates colors based on current appearance.
    ///
    /// - Parameter appearance: The appearance to use for color selection.
    func updateColors(for appearance: NSAppearance?) {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        self.colors = isDark ? Self.darkColors() : Self.lightColors()
    }


    // MARK: Private Methods

    /// Returns default terminal colors.
    private static func defaultColors() -> TerminalColors {
        Self.darkColors()
    }


    /// Returns colors for dark appearance.
    private static func darkColors() -> TerminalColors {
        var colors = TerminalColors()

        // Standard ANSI colors for dark theme
        colors.foregroundColor = TerminalColor(red: 0.87, green: 0.87, blue: 0.87)
        colors.backgroundColor = TerminalColor(red: 0.12, green: 0.12, blue: 0.14)
        colors.cursorColor = TerminalColor(red: 0.87, green: 0.87, blue: 0.87)
        colors.selectionColor = TerminalColor(red: 0.30, green: 0.35, blue: 0.50)

        // ANSI palette
        colors.ansiColors = [
            // Normal colors (0-7)
            TerminalColor(red: 0.00, green: 0.00, blue: 0.00),  // Black
            TerminalColor(red: 0.80, green: 0.25, blue: 0.25),  // Red
            TerminalColor(red: 0.25, green: 0.70, blue: 0.25),  // Green
            TerminalColor(red: 0.80, green: 0.70, blue: 0.25),  // Yellow
            TerminalColor(red: 0.30, green: 0.50, blue: 0.85),  // Blue
            TerminalColor(red: 0.70, green: 0.35, blue: 0.75),  // Magenta
            TerminalColor(red: 0.25, green: 0.70, blue: 0.75),  // Cyan
            TerminalColor(red: 0.75, green: 0.75, blue: 0.75),  // White
            // Bright colors (8-15)
            TerminalColor(red: 0.40, green: 0.40, blue: 0.40),  // Bright Black
            TerminalColor(red: 1.00, green: 0.40, blue: 0.40),  // Bright Red
            TerminalColor(red: 0.40, green: 0.90, blue: 0.40),  // Bright Green
            TerminalColor(red: 1.00, green: 0.90, blue: 0.40),  // Bright Yellow
            TerminalColor(red: 0.50, green: 0.70, blue: 1.00),  // Bright Blue
            TerminalColor(red: 0.90, green: 0.55, blue: 0.95),  // Bright Magenta
            TerminalColor(red: 0.40, green: 0.90, blue: 0.95),  // Bright Cyan
            TerminalColor(red: 1.00, green: 1.00, blue: 1.00),  // Bright White
        ]

        return colors
    }


    /// Returns colors for light appearance.
    private static func lightColors() -> TerminalColors {
        var colors = TerminalColors()

        colors.foregroundColor = TerminalColor(red: 0.15, green: 0.15, blue: 0.15)
        colors.backgroundColor = TerminalColor(red: 1.00, green: 1.00, blue: 1.00)
        colors.cursorColor = TerminalColor(red: 0.15, green: 0.15, blue: 0.15)
        colors.selectionColor = TerminalColor(red: 0.70, green: 0.80, blue: 0.95)

        // ANSI palette for light theme
        colors.ansiColors = [
            // Normal colors (0-7)
            TerminalColor(red: 0.00, green: 0.00, blue: 0.00),  // Black
            TerminalColor(red: 0.75, green: 0.10, blue: 0.10),  // Red
            TerminalColor(red: 0.10, green: 0.55, blue: 0.10),  // Green
            TerminalColor(red: 0.70, green: 0.55, blue: 0.00),  // Yellow
            TerminalColor(red: 0.10, green: 0.30, blue: 0.75),  // Blue
            TerminalColor(red: 0.60, green: 0.20, blue: 0.65),  // Magenta
            TerminalColor(red: 0.10, green: 0.55, blue: 0.60),  // Cyan
            TerminalColor(red: 0.50, green: 0.50, blue: 0.50),  // White
            // Bright colors (8-15)
            TerminalColor(red: 0.30, green: 0.30, blue: 0.30),  // Bright Black
            TerminalColor(red: 0.90, green: 0.25, blue: 0.25),  // Bright Red
            TerminalColor(red: 0.25, green: 0.70, blue: 0.25),  // Bright Green
            TerminalColor(red: 0.85, green: 0.70, blue: 0.15),  // Bright Yellow
            TerminalColor(red: 0.25, green: 0.45, blue: 0.90),  // Bright Blue
            TerminalColor(red: 0.75, green: 0.35, blue: 0.80),  // Bright Magenta
            TerminalColor(red: 0.25, green: 0.70, blue: 0.75),  // Bright Cyan
            TerminalColor(red: 0.20, green: 0.20, blue: 0.20),  // Bright White
        ]

        return colors
    }
}


/// Terminal color configuration.
struct TerminalColors: Sendable {
    var foregroundColor: TerminalColor = TerminalColor(red: 0.87, green: 0.87, blue: 0.87)
    var backgroundColor: TerminalColor = TerminalColor(red: 0.12, green: 0.12, blue: 0.14)
    var cursorColor: TerminalColor = TerminalColor(red: 0.87, green: 0.87, blue: 0.87)
    var selectionColor: TerminalColor = TerminalColor(red: 0.30, green: 0.35, blue: 0.50)
    var ansiColors: [TerminalColor] = []
}


/// Simple color struct for terminal colors.
struct TerminalColor: Sendable {
    let red: Float
    let green: Float
    let blue: Float

    init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var nsColor: NSColor {
        NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
    }

    var swiftTermColor: SwiftTerm.Color {
        SwiftTerm.Color(red: UInt16(red * 65535), green: UInt16(green * 65535), blue: UInt16(blue * 65535))
    }
}
