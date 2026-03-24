//
//  String+RecipeSections.swift
//  OpenCookbook
//
//  Extension to extract RecipeMD sections for split layout display.
//

import Foundation

extension String {
    /// The horizontal rule pattern used in RecipeMD to separate sections
    private static let hrPattern = #"^---+\s*$"#

    /// Split the markdown into sections delimited by horizontal rules.
    /// Returns an array of up to 3 sections: header, ingredients, instructions.
    private func recipeSections() -> [String] {
        let lines = self.components(separatedBy: .newlines)
        var sections: [[String]] = [[]]

        for line in lines {
            if line.range(of: Self.hrPattern, options: .regularExpression) != nil {
                sections.append([])
                if sections.count > 3 { break }
            } else {
                sections[sections.count - 1].append(line)
            }
        }

        return sections.map {
            $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Extracts the header section (everything before the first horizontal rule).
    /// Includes title, description, tags, and yields.
    /// - Returns: The header markdown content, or the full content if no HR found
    func recipeHeaderSection() -> String {
        recipeSections()[0]
    }

    /// Extracts the ingredients section (content between first and second horizontal rule).
    /// - Returns: The ingredients markdown content, or nil if not found
    func recipeIngredientsSection() -> String? {
        let sections = recipeSections()
        guard sections.count > 1 else { return nil }
        let result = sections[1]
        return result.isEmpty ? nil : result
    }

    /// Extracts the instructions section (content after the second horizontal rule).
    /// - Returns: The instructions markdown content, or nil if not found
    func recipeInstructionsSection() -> String? {
        let sections = recipeSections()
        guard sections.count > 2 else { return nil }
        let result = sections[2]
        return result.isEmpty ? nil : result
    }
}
