//
//  RecipeMDParser.swift
//  DoctorRecipe
//
//  Lightweight parser for RecipeMD metadata extraction
//

import Foundation

/// Lightweight parser for extracting metadata from RecipeMD files
/// Only parses what's needed for the recipe list view:
/// - Title (from H1)
/// - Tags (from italic text)
/// - Yields (from bold text)
/// - Description (first paragraph)
final class RecipeMDParser {

    // MARK: - Public Methods

    /// Parse metadata from a RecipeMD file URL
    /// - Parameter url: URL of the .md file to parse
    /// - Returns: A Recipe instance with parsed metadata
    /// - Throws: RecipeParseError if parsing fails
    func parseMetadata(from url: URL) throws -> Recipe {
        // Read file contents
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecipeParseError.fileNotFound
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw RecipeParseError.encodingError
        }

        // Get file modification date for caching
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attributes?[.modificationDate] as? Date

        // Parse metadata
        guard let title = parseTitle(content) else {
            throw RecipeParseError.missingTitle
        }

        let tags = parseTags(content)
        let yields = parseYields(content)
        let description = parseDescription(content)

        return Recipe(
            filePath: url,
            title: title,
            description: description,
            tags: tags,
            yields: yields,
            fileModifiedDate: modDate
        )
    }

    // MARK: - Private Parsing Methods

    /// Extract title from first H1 heading
    /// - Parameter content: The markdown content
    /// - Returns: The title string, or nil if not found
    func parseTitle(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Match H1 heading: # Title
            if trimmed.hasPrefix("# ") {
                let title = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? nil : title
            }
        }

        return nil
    }

    /// Extract tags from italic paragraphs before first HR
    /// Tags are typically in format: *tag1, tag2, tag3*
    /// - Parameter content: The markdown content
    /// - Returns: Array of tag strings
    func parseTags(_ content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var tags: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop at first horizontal rule
            if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") {
                break
            }

            // Look for italic text: *tags* (but not bold **text**)
            if trimmed.hasPrefix("*") && trimmed.hasSuffix("*") && trimmed.count > 2 &&
               !trimmed.hasPrefix("**") {
                let tagText = trimmed.dropFirst().dropLast()
                let parsedTags = tagText.split(separator: ",").map { tag in
                    tag.trimmingCharacters(in: .whitespaces)
                }
                tags.append(contentsOf: parsedTags)
            }
        }

        return tags
    }

    /// Extract yields from bold paragraphs
    /// Yields are typically in format: **4 servings** or **yields: 6 portions**
    /// - Parameter content: The markdown content
    /// - Returns: Array of yield strings
    func parseYields(_ content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var yields: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for bold text: **yields**
            if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") && trimmed.count > 4 {
                var yieldText = String(trimmed.dropFirst(2).dropLast(2))

                // Remove common prefixes like "yields:", "yield:", "serves:", etc.
                let prefixes = ["yields:", "yield:", "serves:", "servings:"]
                for prefix in prefixes {
                    if yieldText.lowercased().hasPrefix(prefix) {
                        yieldText = String(yieldText.dropFirst(prefix.count))
                            .trimmingCharacters(in: .whitespaces)
                        break
                    }
                }

                if !yieldText.isEmpty {
                    yields.append(yieldText)
                }
            }
        }

        return yields
    }

    /// Extract description from first paragraph after title
    /// - Parameter content: The markdown content
    /// - Returns: The description string, or nil if not found
    func parseDescription(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var foundTitle = false
        var descriptionLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip until we find the title
            if !foundTitle {
                if trimmed.hasPrefix("# ") {
                    foundTitle = true
                }
                continue
            }

            // Skip empty lines after title
            if trimmed.isEmpty {
                // If we already have description lines, we've reached the end
                if !descriptionLines.isEmpty {
                    break
                }
                continue
            }

            // Stop at special formatting (tags, yields, headings, HR)
            if trimmed.hasPrefix("#") ||
               trimmed.hasPrefix("*") ||
               trimmed.hasPrefix("**") ||
               trimmed.hasPrefix("---") ||
               trimmed.hasPrefix("***") {
                break
            }

            // Add to description
            descriptionLines.append(trimmed)
        }

        let description = descriptionLines.joined(separator: " ")
        return description.isEmpty ? nil : description
    }
}
