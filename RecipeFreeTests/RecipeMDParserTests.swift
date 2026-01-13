//
//  RecipeMDParserTests.swift
//  RecipeFreeTests
//
//  Unit tests for RecipeMDParser
//

import Testing
import Foundation
@testable import RecipeFree

@Suite("RecipeMD Parser Tests", .serialized)
struct RecipeMDParserTests {

    // Create parser as computed property so each test gets a fresh instance
    var parser: RecipeMDParser { RecipeMDParser() }

    // MARK: - Title Parsing Tests

    @Test("Parse title from H1 heading")
    func parseTitleFromH1() {
        let content = """
        # Chocolate Chip Cookies

        A delicious cookie recipe.
        """

        let title = parser.parseTitle(content)
        #expect(title == "Chocolate Chip Cookies")
    }

    @Test("Parse title with extra whitespace")
    func parseTitleWithWhitespace() {
        let content = """
        #    Pasta Carbonara

        Classic Italian pasta.
        """

        let title = parser.parseTitle(content)
        #expect(title == "Pasta Carbonara")
    }

    @Test("Return nil when no title found")
    func parseTitleMissing() {
        let content = """
        This is just some text.
        No heading here.
        """

        let title = parser.parseTitle(content)
        #expect(title == nil)
    }

    @Test("Ignore H2 and H3 headings")
    func parseTitleIgnoreLowerHeadings() {
        let content = """
        ## This is H2
        ### This is H3
        """

        let title = parser.parseTitle(content)
        #expect(title == nil)
    }

    // MARK: - Tags Parsing Tests

    @Test("Parse tags from italic text")
    func parseTagsFromItalic() {
        let content = """
        # Recipe Title

        *dinner, main course, vegetarian*

        ---
        """

        let tags = parser.parseTags(content)
        #expect(tags == ["dinner", "main course", "vegetarian"])
    }

    @Test("Parse tags with varied spacing")
    func parseTagsWithSpacing() {
        let content = """
        *breakfast,lunch  ,  snack*
        """

        let tags = parser.parseTags(content)
        #expect(tags == ["breakfast", "lunch", "snack"])
    }

    @Test("Stop parsing tags at horizontal rule")
    func parseTagsStopAtHR() {
        let content = """
        *before*

        ---

        *after*
        """

        let tags = parser.parseTags(content)
        #expect(tags == ["before"])
    }

    @Test("Return empty array when no tags found")
    func parseTagsEmpty() {
        let content = """
        # Recipe Title

        Just some description.
        """

        let tags = parser.parseTags(content)
        #expect(tags.isEmpty)
    }

    // MARK: - Yields Parsing Tests

    @Test("Parse yields from bold text")
    func parseYieldsFromBold() {
        let content = """
        # Recipe Title

        **4 servings**
        """

        let yields = parser.parseYields(content)
        #expect(yields == ["4 servings"])
    }

    @Test("Parse yields with 'yields:' prefix")
    func parseYieldsWithPrefix() {
        let content = """
        **yields: 6 portions**
        """

        let yields = parser.parseYields(content)
        #expect(yields == ["6 portions"])
    }

    @Test("Parse yields with 'serves:' prefix")
    func parseYieldsWithServesPrefix() {
        let content = """
        **serves: 8 people**
        """

        let yields = parser.parseYields(content)
        #expect(yields == ["8 people"])
    }

    @Test("Return empty array when no yields found")
    func parseYieldsEmpty() {
        let content = """
        # Recipe Title

        No yields here.
        """

        let yields = parser.parseYields(content)
        #expect(yields.isEmpty)
    }

    // MARK: - Description Parsing Tests

    @Test("Parse description from first paragraph")
    func parseDescriptionFirstParagraph() {
        let content = """
        # Recipe Title

        This is a delicious recipe that everyone will love.

        ## Ingredients
        """

        let description = parser.parseDescription(content)
        #expect(description == "This is a delicious recipe that everyone will love.")
    }

    @Test("Parse multi-line description")
    func parseDescriptionMultiLine() {
        let content = """
        # Recipe Title

        This is line one.
        This is line two.

        ## Next Section
        """

        let description = parser.parseDescription(content)
        #expect(description == "This is line one. This is line two.")
    }

    @Test("Stop description at tags")
    func parseDescriptionStopAtTags() {
        let content = """
        # Recipe Title

        This is the description.

        *tag1, tag2*
        """

        let description = parser.parseDescription(content)
        #expect(description == "This is the description.")
    }

    @Test("Return nil when no description found")
    func parseDescriptionEmpty() {
        let content = """
        # Recipe Title

        *tag1*
        """

        let description = parser.parseDescription(content)
        #expect(description == nil)
    }

    // MARK: - Full Integration Tests

    @Test("Parse complete valid RecipeMD file")
    func parseCompleteRecipe() async throws {
        // Create temporary file with unique name to avoid parallel test conflicts
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_recipe_\(UUID().uuidString).md")

        let content = """
        # Chocolate Chip Cookies

        Classic homemade chocolate chip cookies that are crispy on the outside and chewy on the inside.

        *dessert, baking, cookies*

        **yields: 24 cookies**

        ---

        ## Ingredients

        - 2 cups flour
        - 1 cup sugar
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Parse the file
        let recipe = try parser.parseMetadata(from: fileURL)

        // Verify parsed data
        #expect(recipe.title == "Chocolate Chip Cookies")
        #expect(recipe.description?.contains("Classic homemade") == true)
        #expect(recipe.tags == ["dessert", "baking", "cookies"])
        #expect(recipe.yields == ["24 cookies"])
        #expect(recipe.filePath == fileURL)
        #expect(recipe.fileModifiedDate != nil)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Handle minimal recipe with title only")
    func parseMinimalRecipe() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("minimal_recipe_\(UUID().uuidString).md")

        let content = """
        # Simple Recipe
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipe = try parser.parseMetadata(from: fileURL)

        #expect(recipe.title == "Simple Recipe")
        #expect(recipe.description == nil)
        #expect(recipe.tags.isEmpty)
        #expect(recipe.yields.isEmpty)

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Throw error for missing title")
    func parseRecipeWithoutTitle() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("no_title_\(UUID().uuidString).md")

        let content = """
        This is some content without a title.

        *tag1, tag2*
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(throws: RecipeParseError.self) {
            try parser.parseMetadata(from: fileURL)
        }

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Throw error for non-existent file")
    func parseNonExistentFile() async throws {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_recipe.md")

        #expect(throws: RecipeParseError.self) {
            try parser.parseMetadata(from: fakeURL)
        }
    }

    @Test("Handle malformed markdown gracefully")
    func parseMalformedMarkdown() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("malformed_\(UUID().uuidString).md")

        let content = """
        # Valid Title

        *unclosed italic

        **unclosed bold

        Some random text.
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let recipe = try parser.parseMetadata(from: fileURL)

        // Should still parse the title successfully
        #expect(recipe.title == "Valid Title")

        try? FileManager.default.removeItem(at: fileURL)
    }
}
