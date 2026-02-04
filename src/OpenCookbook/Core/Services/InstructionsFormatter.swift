//
//  InstructionsFormatter.swift
//  OpenCookbook
//
//  Adds auto-numbering to recipe instructions that don't have numbering
//

import Foundation

/// Formats recipe instructions by adding step numbers to unnumbered lines
struct InstructionsFormatter {

    /// Format instructions by adding step numbers if not already numbered
    /// - Parameter instructions: The raw instructions string
    /// - Returns: Formatted instructions with step numbers, or original if already numbered
    func format(_ instructions: String) -> String {
        let lines = instructions.components(separatedBy: "\n")

        // Check if first non-blank line is already numbered
        if let firstContentLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            if isAlreadyNumbered(firstContentLine) {
                return instructions
            }
        }

        var result: [String] = []
        var stepNumber = 1
        var stopped = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Blank line - preserve it
            if trimmed.isEmpty {
                result.append(line)
                continue
            }

            // Check for stop triggers
            if isStopTrigger(trimmed) {
                stopped = true
            }

            // If stopped or already numbered, pass through unchanged
            if stopped {
                result.append(line)
            } else {
                // Add step number
                result.append("\(stepNumber). \(trimmed)")
                stepNumber += 1
            }
        }

        return result.joined(separator: "\n")
    }

    // MARK: - Private Methods

    /// Check if a line indicates the instructions are already numbered
    private func isAlreadyNumbered(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // "1." or "1)" style (digit followed by . or ))
        if trimmed.range(of: #"^\d+[.\)]"#, options: .regularExpression) != nil {
            return true
        }

        // "Step 1:" or "Step 1 -" style
        if trimmed.range(of: #"^[Ss]tep\s+\d+[:\-\s]"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Check if a line is a stop trigger that ends auto-numbering
    private func isStopTrigger(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Header (starts with #)
        if trimmed.hasPrefix("#") {
            return true
        }

        // Horizontal rule (---, ***, ___ with 3+ characters)
        if trimmed.range(of: #"^[-*_]{3,}$"#, options: .regularExpression) != nil {
            return true
        }

        // Italic/emphasis line (starts and ends with * or _)
        // Must have content between the markers
        if trimmed.count >= 3 {
            if (trimmed.hasPrefix("*") && trimmed.hasSuffix("*") && !trimmed.hasPrefix("**")) ||
               (trimmed.hasPrefix("_") && trimmed.hasSuffix("_") && !trimmed.hasPrefix("__")) {
                return true
            }
        }

        return false
    }
}
