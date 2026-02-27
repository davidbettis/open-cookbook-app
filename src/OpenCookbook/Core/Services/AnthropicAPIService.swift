//
//  AnthropicAPIService.swift
//  OpenCookbook
//
//  Anthropic Messages API client for extracting recipes from URLs and photos
//

import Foundation

@MainActor
@Observable
class AnthropicAPIService {
    enum APIError: LocalizedError, Equatable {
        case noAPIKey
        case invalidResponse(statusCode: Int, message: String)
        case decodingError
        case networkError(underlying: String)
        case rateLimited
        case invalidAPIKey
        case notARecipe
        case imageTooLarge

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No API key configured. Add your key in Settings."
            case .invalidResponse(let code, let message):
                if message.isEmpty {
                    return "The Claude API returned an error (HTTP \(code))."
                }
                return "Claude API error: \(message)"
            case .decodingError: return "Could not parse the API response."
            case .networkError: return "Network error contacting the Claude API."
            case .rateLimited: return "Rate limited. Please wait a moment and try again."
            case .invalidAPIKey: return "Your API key is invalid. Update it in Settings."
            case .notARecipe: return "This page doesn't appear to contain a recipe."
            case .imageTooLarge: return "The image is too large. Try a smaller photo or lower resolution."
            }
        }

        static func == (lhs: APIError, rhs: APIError) -> Bool {
            switch (lhs, rhs) {
            case (.noAPIKey, .noAPIKey): return true
            case (.invalidResponse(let a, _), .invalidResponse(let b, _)): return a == b
            case (.decodingError, .decodingError): return true
            case (.networkError, .networkError): return true
            case (.rateLimited, .rateLimited): return true
            case (.invalidAPIKey, .invalidAPIKey): return true
            case (.notARecipe, .notARecipe): return true
            case (.imageTooLarge, .imageTooLarge): return true
            default: return false
            }
        }
    }

    enum ClaudeModel: String, CaseIterable, Identifiable, Sendable {
        case haiku = "claude-haiku-4-5-20251001"
        case sonnet = "claude-sonnet-4-6"
        case opus = "claude-opus-4-6"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .haiku: return "Haiku 4.5 (fastest)"
            case .sonnet: return "Sonnet 4.6 (balanced)"
            case .opus: return "Opus 4.6 (most capable)"
            }
        }
    }

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    /// Send a URL to Claude with web_fetch tool and get a recipe markdown string.
    func extractRecipe(
        from url: String,
        apiKey: String,
        model: ClaudeModel,
        tagPrompt: String = ""
    ) async throws(APIError) -> String {
        let prompt = Self.buildPrompt(url: url, tagPrompt: tagPrompt)
        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 8192,
            "messages": [["role": "user", "content": prompt]],
            "tools": [
                [
                    "type": "web_fetch_20250910",
                    "name": "web_fetch",
                    "max_uses": 1,
                    "max_content_tokens": 50000
                ] as [String: Any]
            ]
        ]

        return try await extractRecipeFromResponse(apiKey: apiKey, body: body)
    }

    /// Extract a recipe from a photo by sending the image to Claude.
    func extractRecipeFromImage(
        imageData: Data,
        mediaType: String,
        apiKey: String,
        model: ClaudeModel,
        tagPrompt: String = ""
    ) async throws(APIError) -> String {
        let base64Image = imageData.base64EncodedString()
        let prompt = Self.buildPhotoPrompt(tagPrompt: tagPrompt)

        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 8192,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mediaType,
                                "data": base64Image
                            ] as [String: Any]
                        ] as [String: Any],
                        [
                            "type": "text",
                            "text": prompt
                        ] as [String: Any]
                    ]
                ] as [String: Any]
            ]
        ]

        return try await extractRecipeFromResponse(apiKey: apiKey, body: body)
    }

    /// Verify the API key with a minimal request.
    func verifyAPIKey(_ apiKey: String) async throws(APIError) -> Bool {
        let body: [String: Any] = [
            "model": ClaudeModel.haiku.rawValue,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]

        _ = try await sendRequest(apiKey: apiKey, body: body)
        return true
    }

    /// Strip markdown image syntax `![...](...)` from text.
    static func stripImageSyntax(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"!\[.*?\]\(.*?\)"#,
            with: "",
            options: .regularExpression
        )
    }

    /// Shared recipe formatting instructions used by both website and photo prompts.
    static func recipeExtractionInstructions(tagPrompt: String) -> String {
        var instructions = """
        Format the recipe with these exact specifications:
        1. Title: Use H1 heading (single #)
        2. Tags: On the next line, add italicized tags separated by commas (e.g., asian, slow-cooker)
        3. Servings: Bold text showing servings and portion size (e.g., ** 6 Servings, 1.5 cups **)
        4. Separator: Add a horizontal rule (---)
        5. Ingredients List:
           * Each ingredient on its own line starting with a dash
           * Italicize quantities (e.g., *2 1/2 lb*, *1/2 c*, *1 T*)
           * Use slash fractions (1/2, 1/4, 3/4) instead of unicode fractions
           * Follow quantity with ingredient description
           * Maintain original measurements and abbreviations
           * Do not include a heading that says "Ingredients" for this section.
        6. Separator: Add another horizontal rule (---)
        7. Instructions:
           * Number each step
           * Use clear, sequential formatting
           * Maintain original wording and details
           * Do not include a heading that says "Instructions" for this section.
        8. Attribution: If source information is provided, add it at the end in the format: "*Attribution:* [Author Name], [URL]"
        Preserve all recipe details including ingredient amounts, cooking times, temperatures, and special notes. Format any garnishes, serving suggestions, or optional ingredients as separate ingredient lines.

        Important rules:
        - Do NOT include any images, image links, or markdown image syntax (![...](...)). The output must be plain text and markdown only.
        - If the content does not contain a recipe, respond with exactly: NOT_A_RECIPE
        - Do not attempt to fabricate a recipe from non-recipe content.
        - Do NOT wrap your response in code fences. Output the raw markdown directly.

        Output ONLY the recipe markdown, with no preamble or commentary.
        """

        if !tagPrompt.isEmpty {
            instructions += "\n\n" + tagPrompt
        }

        return instructions
    }

    /// Build the extraction prompt with URL interpolated.
    static func buildPrompt(url: String, tagPrompt: String = "") -> String {
        """
        Fetch the following URL and extract the recipe into structured markdown format:

        \(url)

        \(recipeExtractionInstructions(tagPrompt: tagPrompt))
        """
    }

    /// Build the extraction prompt for a photo.
    static func buildPhotoPrompt(tagPrompt: String = "") -> String {
        """
        Extract the recipe from this photo into structured markdown format.

        \(recipeExtractionInstructions(tagPrompt: tagPrompt))
        """
    }

    // MARK: - Private

    /// Shared response parsing for both website and photo extraction.
    private func extractRecipeFromResponse(apiKey: String, body: [String: Any]) async throws(APIError) -> String {
        let data = try await sendRequest(apiKey: apiKey, body: body)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw .decodingError
        }

        // Find the last text block — for website imports this is Claude's analysis
        // after fetching the page; for photo imports it's the direct response.
        guard let text = content.last(where: { $0["type"] as? String == "text" })?["text"] as? String else {
            throw .decodingError
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines) == "NOT_A_RECIPE" {
            throw .notARecipe
        }

        return Self.stripImageSyntax(text)
    }

    /// Send a request to the Anthropic Messages API and handle common error responses.
    private func sendRequest(apiKey: String, body: [String: Any]) async throws(APIError) -> Data {
        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .networkError(underlying: error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            // Parse the API error message from the response body
            let apiMessage = Self.parseErrorMessage(from: data)

            switch http.statusCode {
            case 401: throw .invalidAPIKey
            case 429: throw .rateLimited
            default: throw .invalidResponse(statusCode: http.statusCode, message: apiMessage)
            }
        }

        return data
    }

    /// Parse the error message from an Anthropic API error response.
    /// Format: {"type": "error", "error": {"type": "...", "message": "..."}}
    private static func parseErrorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return message
    }
}
