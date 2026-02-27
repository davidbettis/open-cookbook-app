//
//  RecipeSearchService.swift
//  OpenCookbook
//
//  Service for searching and filtering recipes
//

import Foundation
import Combine
import RecipeMD

/// Service for searching and filtering recipes with debouncing
@MainActor
@Observable
final class RecipeSearchService {

    // MARK: - Properties

    /// Current search text
    var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
        }
    }

    /// Debounced search text (updates after 250ms delay)
    private(set) var debouncedSearchText: String = ""

    /// Currently selected tags for filtering
    var selectedTags: Set<String> = []

    /// All available tags extracted from recipes
    private(set) var availableTags: [TagInfo] = []

    /// Filtered recipes based on search and tag filters
    private(set) var filteredRecipes: [RecipeFile] = []

    /// Whether any filters are active
    var hasActiveFilters: Bool {
        !debouncedSearchText.isEmpty || !selectedTags.isEmpty
    }

    /// Result count message for display
    var resultCountMessage: String {
        if !hasActiveFilters {
            return ""
        }
        let count = filteredRecipes.count
        if count == 0 {
            return "No recipes match your search"
        } else if count == 1 {
            return "1 recipe found"
        } else {
            return "\(count) recipes found"
        }
    }

    // MARK: - Private Properties

    private let searchTextSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var allRecipes: [RecipeFile] = []

    // MARK: - Initialization

    init() {
        setupDebounce()
    }

    // MARK: - Public Methods

    /// Update the recipe collection and recalculate filters
    /// - Parameter recipes: The full collection of recipe files
    func updateRecipes(_ recipes: [RecipeFile]) {
        allRecipes = recipes
        extractTags()
        applyFilters()
    }

    /// Toggle a tag selection
    /// - Parameter tag: The tag to toggle
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        applyFilters()
    }

    /// Clear all filters (search text and selected tags)
    func clearAllFilters() {
        searchText = ""
        debouncedSearchText = ""
        selectedTags.removeAll()
        applyFilters()
    }

    /// Clear only the search text
    func clearSearch() {
        searchText = ""
        debouncedSearchText = ""
        applyFilters()
    }

    /// Clear only the tag filters
    func clearTagFilters() {
        selectedTags.removeAll()
        applyFilters()
    }

    // MARK: - Private Methods

    private func setupDebounce() {
        searchTextSubject
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.debouncedSearchText = text
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    /// Extract all unique tags from recipes with counts
    private func extractTags() {
        var tagCounts: [String: Int] = [:]

        for recipeFile in allRecipes {
            for tag in recipeFile.tags {
                let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespaces)
                tagCounts[normalizedTag, default: 0] += 1
            }
        }

        // Sort tags alphabetically and create TagInfo objects
        availableTags = tagCounts
            .map { TagInfo(name: $0.key, count: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Apply search and tag filters to the recipe collection
    private func applyFilters() {
        var results = allRecipes

        // Apply tag filter (AND logic - all selected tags must match)
        if !selectedTags.isEmpty {
            results = results.filter { recipeFile in
                let recipeTags = Set(recipeFile.tags.map { $0.lowercased() })
                return selectedTags.allSatisfy { recipeTags.contains($0) }
            }
        }

        // Apply search filter
        if !debouncedSearchText.isEmpty {
            let searchTerm = debouncedSearchText.lowercased()
            results = results.filter { recipeFile in
                matchesSearch(recipeFile: recipeFile, searchTerm: searchTerm)
            }
        }

        filteredRecipes = results
    }

    /// Check if a recipe matches the search term
    /// - Parameters:
    ///   - recipeFile: The recipe file to check
    ///   - searchTerm: The lowercased search term
    /// - Returns: True if the recipe matches
    private func matchesSearch(recipeFile: RecipeFile, searchTerm: String) -> Bool {
        let recipe = recipeFile.recipe

        // Check title
        if recipe.title.lowercased().contains(searchTerm) {
            return true
        }

        // Check description
        if let description = recipe.description,
           description.lowercased().contains(searchTerm) {
            return true
        }

        // Check tags
        if recipe.tags.contains(where: { $0.lowercased().contains(searchTerm) }) {
            return true
        }

        // Check all ingredients from all groups
        let allIngredients = recipe.ingredientGroups.flatMap { $0.allIngredients }
        if allIngredients.contains(where: { $0.name.lowercased().contains(searchTerm) }) {
            return true
        }

        // Check instructions
        if let instructions = recipe.instructions,
           instructions.lowercased().contains(searchTerm) {
            return true
        }

        return false
    }
}

// MARK: - Supporting Types

/// Information about a tag including its usage count
struct TagInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let count: Int
}

/// Tag frequency with category information for the tag picker and AI prompt
struct TagFrequency: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let count: Int
    let category: TagVocabulary.Category?  // nil = custom

    var isBuiltIn: Bool { category != nil }
}

// MARK: - Tag Frequency Helpers

extension RecipeSearchService {

    /// Compute tag frequencies from a recipe list.
    /// Returns all built-in tags (0 if unused) + custom tags, sorted by count desc then alpha.
    static func computeTagFrequencies(from recipes: [RecipeFile]) -> [TagFrequency] {
        var tagCounts: [String: Int] = [:]

        for recipe in recipes {
            for tag in recipe.tags {
                let normalized = tag.lowercased().trimmingCharacters(in: .whitespaces)
                guard !normalized.isEmpty else { continue }
                tagCounts[normalized, default: 0] += 1
            }
        }

        var frequencies: [TagFrequency] = []

        // Add all built-in tags (with 0 count if unused)
        for category in TagVocabulary.Category.allCases {
            for tag in category.tags {
                frequencies.append(TagFrequency(
                    name: tag,
                    count: tagCounts[tag] ?? 0,
                    category: category
                ))
            }
        }

        // Add custom tags (not in built-in vocabulary)
        let builtIn = TagVocabulary.allBuiltInTags
        for (tag, count) in tagCounts where !builtIn.contains(tag) {
            frequencies.append(TagFrequency(
                name: tag,
                count: count,
                category: nil
            ))
        }

        // Sort: descending count, then alphabetical for ties
        frequencies.sort { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return frequencies
    }

    /// Format tag frequencies as an AI prompt string.
    static func tagFrequencyPrompt(from recipes: [RecipeFile]) -> String {
        let frequencies = computeTagFrequencies(from: recipes)
        guard !frequencies.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("Tags: Select 2-4 tags from ONLY this list, preferring tags near the top:")

        for freq in frequencies {
            let prefix = freq.isBuiltIn ? "- " : "- [Custom] "
            let suffix = freq.count == 1 ? "recipe" : "recipes"
            lines.append("\(prefix)\(freq.name) (\(freq.count) \(suffix))")
        }

        lines.append("Do NOT invent tags outside this list.")

        return lines.joined(separator: "\n")
    }
}
