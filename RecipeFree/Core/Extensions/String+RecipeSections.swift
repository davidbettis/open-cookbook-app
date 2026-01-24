//
//  String+RecipeSections.swift
//  RecipeFree
//
//  Extension to extract RecipeMD sections for split layout display.
//

import Foundation

extension String {
    /// The horizontal rule pattern used in RecipeMD to separate sections
    private static let hrPattern = #"^---+\s*$"#

    /// Extracts the header section (everything before the first horizontal rule).
    /// Includes title, description, tags, and yields.
    /// - Returns: The header markdown content, or the full content if no HR found
    func recipeHeaderSection() -> String {
        let lines = self.components(separatedBy: .newlines)
        var headerLines: [String] = []

        for line in lines {
            if line.range(of: Self.hrPattern, options: .regularExpression) != nil {
                break
            }
            headerLines.append(line)
        }

        return headerLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts the ingredients section (content between first and second horizontal rule).
    /// - Returns: The ingredients markdown content, or nil if not found
    func recipeIngredientsSection() -> String? {
        let lines = self.components(separatedBy: .newlines)
        var ingredientLines: [String] = []
        var hrCount = 0
        var inIngredients = false

        for line in lines {
            if line.range(of: Self.hrPattern, options: .regularExpression) != nil {
                hrCount += 1
                if hrCount == 1 {
                    inIngredients = true
                    continue
                } else if hrCount == 2 {
                    break
                }
            }

            if inIngredients {
                ingredientLines.append(line)
            }
        }

        let result = ingredientLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// Extracts the instructions section (content after the second horizontal rule).
    /// - Returns: The instructions markdown content, or nil if not found
    func recipeInstructionsSection() -> String? {
        let lines = self.components(separatedBy: .newlines)
        var instructionLines: [String] = []
        var hrCount = 0
        var inInstructions = false

        for line in lines {
            if line.range(of: Self.hrPattern, options: .regularExpression) != nil {
                hrCount += 1
                if hrCount == 2 {
                    inInstructions = true
                    continue
                }
            }

            if inInstructions {
                instructionLines.append(line)
            }
        }

        let result = instructionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
