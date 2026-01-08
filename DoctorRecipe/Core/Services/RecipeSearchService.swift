//
//  RecipeSearchService.swift
//  DoctorRecipe
//
//  Service for searching and filtering recipes
//

import Foundation
import Combine

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
    private(set) var filteredRecipes: [Recipe] = []

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
    private var allRecipes: [Recipe] = []

    // MARK: - Initialization

    init() {
        setupDebounce()
    }

    // MARK: - Public Methods

    /// Update the recipe collection and recalculate filters
    /// - Parameter recipes: The full collection of recipes
    func updateRecipes(_ recipes: [Recipe]) {
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

        for recipe in allRecipes {
            for tag in recipe.tags {
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
            results = results.filter { recipe in
                let recipeTags = Set(recipe.tags.map { $0.lowercased() })
                return selectedTags.allSatisfy { recipeTags.contains($0) }
            }
        }

        // Apply search filter
        if !debouncedSearchText.isEmpty {
            let searchTerm = debouncedSearchText.lowercased()
            results = results.filter { recipe in
                matchesSearch(recipe: recipe, searchTerm: searchTerm)
            }
        }

        filteredRecipes = results
    }

    /// Check if a recipe matches the search term
    /// - Parameters:
    ///   - recipe: The recipe to check
    ///   - searchTerm: The lowercased search term
    /// - Returns: True if the recipe matches
    private func matchesSearch(recipe: Recipe, searchTerm: String) -> Bool {
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

        // Check ingredients (name only for now)
        if recipe.ingredients.contains(where: { $0.name.lowercased().contains(searchTerm) }) {
            return true
        }

        // Check ingredient groups
        for group in recipe.ingredientGroups {
            if group.ingredients.contains(where: { $0.name.lowercased().contains(searchTerm) }) {
                return true
            }
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
