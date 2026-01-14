//
//  Amount+Scaling.swift
//  RecipeFree
//
//  Extension for scaling RecipeMD Amount values
//

import Foundation
import RecipeMD

extension Amount {
    /// Returns a formatted string with the amount scaled by the given multiplier
    /// - Parameter multiplier: The scaling factor (e.g., 0.5 for half, 2.0 for double)
    /// - Returns: Formatted string with scaled amount and unit
    func formattedScaled(by multiplier: Double) -> String {
        let scaledValue = self.amount * multiplier
        let formattedNumber = Self.formatNumber(scaledValue)

        if let unit = self.unit, !unit.isEmpty {
            return "\(formattedNumber) \(unit)"
        }
        return formattedNumber
    }

    /// Formats a number cleanly, removing unnecessary decimals
    /// - Parameter value: The number to format
    /// - Returns: Formatted string
    private static func formatNumber(_ value: Double) -> String {
        // Check if it's effectively a whole number
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }

        // Check for clean halves and quarters
        let remainder = value.truncatingRemainder(dividingBy: 0.25)
        if abs(remainder) < 0.001 {
            // It's a clean quarter, format with one decimal
            if value.truncatingRemainder(dividingBy: 0.5) == 0 {
                return String(format: "%.1f", value)
            }
            return String(format: "%.2f", value)
        }

        // For other decimals, use up to 2 decimal places and trim trailing zeros
        let formatted = String(format: "%.2f", value)
        // Remove trailing zeros after decimal
        if formatted.contains(".") {
            var trimmed = formatted
            while trimmed.hasSuffix("0") {
                trimmed.removeLast()
            }
            if trimmed.hasSuffix(".") {
                trimmed.removeLast()
            }
            return trimmed
        }
        return formatted
    }
}
