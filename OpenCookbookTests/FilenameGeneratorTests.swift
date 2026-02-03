//
//  FilenameGeneratorTests.swift
//  OpenCookbookTests
//
//  Tests for filename generation and slugification
//

import Foundation
import Testing
@testable import OpenCookbook

struct FilenameGeneratorTests {

    let generator = FilenameGenerator()

    // MARK: - Slugification Tests

    @Test("Slugifies simple title")
    func slugifiesSimpleTitle() {
        let slug = "Chocolate Chip Cookies".slugified
        #expect(slug == "chocolate-chip-cookies")
    }

    @Test("Slugifies title with special characters")
    func slugifiesSpecialCharacters() {
        let slug = "Mom's \"Special\" Cookies!".slugified
        #expect(slug == "moms-special-cookies")
    }

    @Test("Slugifies title with multiple spaces")
    func slugifiesMultipleSpaces() {
        let slug = "Pasta   with    Sauce".slugified
        #expect(slug == "pasta-with-sauce")
    }

    @Test("Slugifies title with underscores")
    func slugifiesUnderscores() {
        let slug = "my_favorite_recipe".slugified
        #expect(slug == "my-favorite-recipe")
    }

    @Test("Slugifies title with numbers")
    func slugifiesNumbers() {
        let slug = "Recipe #1 - 2024 Edition".slugified
        #expect(slug == "recipe-1-2024-edition")
    }

    @Test("Handles leading and trailing special characters")
    func handlesLeadingTrailingSpecials() {
        let slug = "---Recipe Name---".slugified
        #expect(slug == "recipe-name")
    }

    @Test("Handles empty result after sanitization")
    func handlesEmptyResult() {
        let slug = "!!!@@@###".slugified
        #expect(slug == "")
    }

    // MARK: - Filename Generation Tests

    @Test("Generates basic filename")
    func generatesBasicFilename() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let filename = try generator.generateFilename(for: "Chocolate Chip Cookies", in: tempDir)
        #expect(filename == "chocolate-chip-cookies.md")
    }

    @Test("Handles duplicate filenames")
    func handlesDuplicateFilenames() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create first file
        let firstFile = tempDir.appendingPathComponent("pancakes.md")
        try "# Pancakes".write(to: firstFile, atomically: true, encoding: .utf8)

        // Generate filename for same title
        let filename = try generator.generateFilename(for: "Pancakes", in: tempDir)
        #expect(filename == "pancakes-1.md")
    }

    @Test("Handles multiple duplicates")
    func handlesMultipleDuplicates() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create multiple files
        try "# Pancakes".write(to: tempDir.appendingPathComponent("pancakes.md"), atomically: true, encoding: .utf8)
        try "# Pancakes".write(to: tempDir.appendingPathComponent("pancakes-1.md"), atomically: true, encoding: .utf8)
        try "# Pancakes".write(to: tempDir.appendingPathComponent("pancakes-2.md"), atomically: true, encoding: .utf8)

        let filename = try generator.generateFilename(for: "Pancakes", in: tempDir)
        #expect(filename == "pancakes-3.md")
    }

    @Test("Throws for empty title")
    func throwsForEmptyTitle() throws {
        let tempDir = FileManager.default.temporaryDirectory

        #expect(throws: FilenameGenerator.FilenameError.emptyTitle) {
            _ = try generator.generateFilename(for: "", in: tempDir)
        }
    }

    @Test("Throws for whitespace-only title")
    func throwsForWhitespaceTitle() throws {
        let tempDir = FileManager.default.temporaryDirectory

        #expect(throws: FilenameGenerator.FilenameError.emptyTitle) {
            _ = try generator.generateFilename(for: "   ", in: tempDir)
        }
    }

    @Test("Throws when slug is empty after sanitization")
    func throwsForUnsanitizableTitle() throws {
        let tempDir = FileManager.default.temporaryDirectory

        #expect(throws: FilenameGenerator.FilenameError.emptySlug) {
            _ = try generator.generateFilename(for: "!!!@@@", in: tempDir)
        }
    }

    // MARK: - File URL Generation

    @Test("Generates file URL")
    func generatesFileURL() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = try generator.generateFileURL(for: "Test Recipe", in: tempDir)

        #expect(url.lastPathComponent == "test-recipe.md")
        // Compare paths instead of URLs to avoid trailing slash issues
        #expect(url.deletingLastPathComponent().path == tempDir.path)
    }
}
