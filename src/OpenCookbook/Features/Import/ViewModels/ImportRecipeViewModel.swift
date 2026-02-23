//
//  ImportRecipeViewModel.swift
//  OpenCookbook
//
//  Orchestrates the import flow: validate input -> call Claude API -> parse result
//

import Foundation
import os.log
import RecipeMD
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

private let logger = Logger(subsystem: "com.opencookbook", category: "Import")

@MainActor
@Observable
class ImportRecipeViewModel {
    enum ImportSource: String, CaseIterable, Identifiable {
        case website
        case photo

        var id: String { rawValue }
    }

    enum ImportState: Equatable {
        case idle
        case extractingRecipe
        case success(String)
        case error(String)
    }

    var source: ImportSource = .website
    var urlText: String = ""
    var selectedImageData: Data? = nil
    var selectedImageMediaType: String = "image/jpeg"
    var state: ImportState = .idle

    @ObservationIgnored
    @AppStorage("claudeModel") private var claudeModelRawValue: String = AnthropicAPIService.ClaudeModel.sonnet.rawValue

    var isImporting: Bool {
        if case .extractingRecipe = state { return true }
        return false
    }

    var statusMessage: String {
        switch state {
        case .extractingRecipe:
            return source == .website
                ? "Extracting recipe with Claude..."
                : "Extracting recipe from photo..."
        default: return ""
        }
    }

    var hasAPIKey: Bool {
        guard let key = try? KeychainService.read(key: "anthropic-api-key") else { return false }
        return !key.isEmpty
    }

    func importRecipe() async {
        switch source {
        case .website:
            await importFromWebsite()
        case .photo:
            await importFromPhoto()
        }
    }

    // MARK: - Website Import

    private func importFromWebsite() async {
        guard let url = URL(string: urlText),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else {
            state = .error("Please enter a valid URL.")
            return
        }

        do {
            guard let apiKey = try KeychainService.read(key: "anthropic-api-key"), !apiKey.isEmpty else {
                state = .error("No API key configured. Add your key in Settings.")
                return
            }
            let model = AnthropicAPIService.ClaudeModel(rawValue: claudeModelRawValue) ?? .sonnet

            state = .extractingRecipe
            logger.debug("Importing recipe from \(self.urlText) using model \(model.rawValue)")

            let service = AnthropicAPIService()
            let rawMarkdown = try await service.extractRecipe(
                from: urlText,
                apiKey: apiKey,
                model: model
            )

            #if DEBUG
            logger.debug("Raw Claude response (\(rawMarkdown.count) chars):\n\(rawMarkdown)")
            #endif

            let markdown = Self.cleanMarkdown(rawMarkdown)

            #if DEBUG
            logger.debug("Cleaned markdown (\(markdown.count) chars):\n\(markdown)")
            #endif

            // Verify it looks like a recipe (starts with # title) but don't
            // require a full strict parse — the form can handle imperfect markdown
            let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("# ") else {
                logger.error("Response does not start with '# ' — not a valid recipe heading")
                state = .error("Could not extract a recipe from this page. Try a different URL.")
                return
            }

            state = .success(markdown)
        } catch let error as AnthropicAPIService.APIError {
            logger.error("API error: \(error.errorDescription ?? "unknown")")
            state = .error(error.errorDescription ?? "An unknown error occurred.")
        } catch {
            logger.error("Import failed: \(error.localizedDescription)")
            state = .error("Could not extract a recipe from this page. Try a different URL.")
        }
    }

    // MARK: - Photo Import

    private func importFromPhoto() async {
        guard let imageData = selectedImageData else {
            state = .error("No photo selected.")
            return
        }

        do {
            guard let apiKey = try KeychainService.read(key: "anthropic-api-key"), !apiKey.isEmpty else {
                state = .error("No API key configured. Add your key in Settings.")
                return
            }
            let model = AnthropicAPIService.ClaudeModel(rawValue: claudeModelRawValue) ?? .sonnet

            state = .extractingRecipe
            logger.debug("Importing recipe from photo (\(imageData.count) bytes) using model \(model.rawValue)")

            let service = AnthropicAPIService()
            let rawMarkdown = try await service.extractRecipeFromImage(
                imageData: imageData,
                mediaType: selectedImageMediaType,
                apiKey: apiKey,
                model: model
            )

            #if DEBUG
            logger.debug("Raw Claude response (\(rawMarkdown.count) chars):\n\(rawMarkdown)")
            #endif

            let markdown = Self.cleanMarkdown(rawMarkdown)

            #if DEBUG
            logger.debug("Cleaned markdown (\(markdown.count) chars):\n\(markdown)")
            #endif

            let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("# ") else {
                logger.error("Response does not start with '# ' — not a valid recipe heading")
                state = .error("Could not extract a recipe from this photo. Try a different photo.")
                return
            }

            state = .success(markdown)
        } catch let error as AnthropicAPIService.APIError {
            logger.error("API error: \(error.errorDescription ?? "unknown")")
            state = .error(error.errorDescription ?? "An unknown error occurred.")
        } catch {
            logger.error("Import failed: \(error.localizedDescription)")
            state = .error("Could not extract a recipe from this photo. Try a different photo.")
        }
    }

    // MARK: - Image Resizing

    #if canImport(UIKit)
    /// Resize a UIImage to fit within maxBytes when JPEG-encoded.
    /// The API limit is ~5MB for base64-encoded data; default maxBytes accounts for 33% base64 expansion.
    static func resizeImageIfNeeded(_ image: UIImage, maxBytes: Int = 3_750_000) -> Data? {
        // Try compression first, stepping down quality
        var quality: CGFloat = 0.8
        while quality > 0.1 {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }

        // If still too large, scale down dimensions and retry
        let scale: CGFloat = 0.5
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
    #endif

    // MARK: - Markdown Cleaning

    /// Extract the recipe markdown from Claude's response.
    /// Handles: code fences (embedded or wrapping), preamble text, trailing caveats.
    static func cleanMarkdown(_ text: String) -> String {
        // Strategy 1: Extract content from code fences (```markdown ... ``` or ``` ... ```)
        // The fences may be embedded within surrounding prose.
        if let fenced = extractFromCodeFence(text) {
            return fenced.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strategy 2: Find the first # heading and take everything from there
        if let headingRange = text.range(of: "\n# ", options: []) {
            let fromHeading = String(text[text.index(after: headingRange.lowerBound)...])
            return fromHeading.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strategy 3: Response starts with # heading directly
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("# ") {
            return trimmed
        }

        // Give up — return as-is
        return trimmed
    }

    /// Extract content between the first pair of code fences in the text.
    private static func extractFromCodeFence(_ text: String) -> String? {
        // Find opening fence: ``` optionally followed by "markdown" or "md" then newline
        guard let openRange = text.range(of: "```") else { return nil }

        // Find the end of the opening fence line
        let afterOpen = text[openRange.upperBound...]
        guard let firstNewline = afterOpen.firstIndex(of: "\n") else { return nil }
        let contentStart = text.index(after: firstNewline)

        // Find closing fence after the content start
        let remaining = text[contentStart...]
        guard let closeRange = remaining.range(of: "\n```", options: []) else {
            // Try closing fence at end of string
            if remaining.hasSuffix("```") {
                let contentEnd = remaining.index(remaining.endIndex, offsetBy: -3)
                return String(remaining[..<contentEnd])
            }
            return nil
        }

        return String(remaining[..<closeRange.lowerBound])
    }
}
