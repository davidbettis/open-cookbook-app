//
//  AnthropicAPIServiceTests.swift
//  OpenCookbookTests
//
//  Tests for AnthropicAPIService
//

import Foundation
import Testing
@testable import OpenCookbook

@MainActor
@Suite("AnthropicAPIService Tests")
struct AnthropicAPIServiceTests {

    @Test("ClaudeModel has correct display names")
    func modelDisplayNames() {
        #expect(AnthropicAPIService.ClaudeModel.haiku.displayName == "Haiku 4.5 (fastest)")
        #expect(AnthropicAPIService.ClaudeModel.sonnet.displayName == "Sonnet 4.6 (balanced)")
        #expect(AnthropicAPIService.ClaudeModel.opus.displayName == "Opus 4.6 (most capable)")
    }

    @Test("ClaudeModel has correct raw model IDs")
    func modelRawValues() {
        #expect(AnthropicAPIService.ClaudeModel.haiku.rawValue == "claude-haiku-4-5-20251001")
        #expect(AnthropicAPIService.ClaudeModel.sonnet.rawValue == "claude-sonnet-4-6")
        #expect(AnthropicAPIService.ClaudeModel.opus.rawValue == "claude-opus-4-6")
    }

    @Test("Image syntax stripped from response")
    func stripImageSyntax() {
        let input = "# Recipe\n![photo](https://example.com/img.jpg)\n- *1 cup* flour"
        let cleaned = AnthropicAPIService.stripImageSyntax(input)
        #expect(!cleaned.contains("!["))
        #expect(cleaned.contains("- *1 cup* flour"))
    }

    @Test("Image syntax stripped preserves surrounding text")
    func stripImageSyntaxPreservesText() {
        let input = "Some text ![alt](url) more text"
        let cleaned = AnthropicAPIService.stripImageSyntax(input)
        #expect(cleaned == "Some text  more text")
    }

    @Test("No image syntax unchanged")
    func noImageSyntaxUnchanged() {
        let input = "# Recipe\n- *1 cup* flour"
        let cleaned = AnthropicAPIService.stripImageSyntax(input)
        #expect(cleaned == input)
    }

    @Test("Prompt includes URL")
    func promptContainsURL() {
        let prompt = AnthropicAPIService.buildPrompt(url: "https://example.com/recipe")
        #expect(prompt.contains("https://example.com/recipe"))
        #expect(prompt.contains("NOT_A_RECIPE"))
    }

    @Test("Prompt includes formatting instructions")
    func promptContainsInstructions() {
        let prompt = AnthropicAPIService.buildPrompt(url: "https://example.com")
        #expect(prompt.contains("H1 heading"))
        #expect(prompt.contains("horizontal rule"))
        #expect(prompt.contains("Italicize quantities"))
    }

    @Test("ClaudeModel is identifiable by raw value")
    func modelIdentifiable() {
        for model in AnthropicAPIService.ClaudeModel.allCases {
            #expect(model.id == model.rawValue)
        }
    }

    // MARK: - Photo Prompt Tests

    @Test("Photo prompt includes formatting instructions")
    func photoPromptContainsInstructions() {
        let prompt = AnthropicAPIService.buildPhotoPrompt()
        #expect(prompt.contains("H1 heading"))
        #expect(prompt.contains("horizontal rule"))
        #expect(prompt.contains("Italicize quantities"))
        #expect(prompt.contains("NOT_A_RECIPE"))
    }

    @Test("Photo prompt has photo-specific preamble")
    func photoPromptPreamble() {
        let prompt = AnthropicAPIService.buildPhotoPrompt()
        #expect(prompt.contains("Extract the recipe from this photo"))
    }

    @Test("Photo prompt does not contain URL-related text")
    func photoPromptNoURL() {
        let prompt = AnthropicAPIService.buildPhotoPrompt()
        #expect(!prompt.contains("Fetch the following URL"))
    }

    @Test("Website and photo prompts share formatting instructions")
    func sharedInstructions() {
        let websitePrompt = AnthropicAPIService.buildPrompt(url: "https://example.com")
        let photoPrompt = AnthropicAPIService.buildPhotoPrompt()
        // Both should contain the shared extraction instructions
        #expect(websitePrompt.contains(AnthropicAPIService.recipeExtractionInstructions))
        #expect(photoPrompt.contains(AnthropicAPIService.recipeExtractionInstructions))
    }

    @Test("imageTooLarge error has correct description")
    func imageTooLargeError() {
        let error = AnthropicAPIService.APIError.imageTooLarge
        #expect(error.errorDescription?.contains("too large") == true)
    }
}
