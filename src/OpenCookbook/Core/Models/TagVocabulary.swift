//
//  TagVocabulary.swift
//  OpenCookbook
//
//  Built-in tag vocabulary organized by category
//

import Foundation

struct TagVocabulary {
    enum Category: String, CaseIterable, Identifiable {
        case cuisine
        case meal
        case method
        case diet
        case protein

        var id: String { rawValue }

        var displayName: String { rawValue.capitalized }

        var tags: [String] {
            switch self {
            case .cuisine:
                return [
                    "american", "asian", "chinese", "french", "greek", "indian",
                    "italian", "japanese", "korean", "mediterranean",
                    "mexican", "middle-eastern", "southern", "thai", "vietnamese"
                ]
            case .meal:
                return [
                    "appetizer", "main", "snack", "dessert", "baking",
                    "breakfast", "brunch"
                ]
            case .method:
                return [
                    "oven", "grilled", "fried", "slow-cooker", "instant-pot",
                    "one-pot", "no-cook", "stir-fry"
                ]
            case .diet:
                return ["vegetarian", "vegan", "gluten-free", "dairy-free"]
            case .protein:
                return [
                    "chicken", "beef", "pork", "lamb", "seafood",
                    "fish", "shrimp", "tofu", "eggs"
                ]
            }
        }
    }

    static let allBuiltInTags: Set<String> = {
        var tags = Set<String>()
        for category in Category.allCases {
            tags.formUnion(category.tags)
        }
        return tags
    }()

    static func isBuiltIn(_ tag: String) -> Bool {
        allBuiltInTags.contains(tag.lowercased())
    }

    static func category(for tag: String) -> Category? {
        let normalized = tag.lowercased()
        return Category.allCases.first { $0.tags.contains(normalized) }
    }
}
