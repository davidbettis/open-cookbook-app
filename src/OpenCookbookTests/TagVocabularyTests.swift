//
//  TagVocabularyTests.swift
//  OpenCookbookTests
//
//  Tests for TagVocabulary model
//

import Foundation
import Testing
@testable import OpenCookbook

@Suite("TagVocabulary")
struct TagVocabularyTests {

    @Test("All built-in tags total 43")
    func allBuiltInTagsCount() {
        #expect(TagVocabulary.allBuiltInTags.count == 43)
    }

    @Test("isBuiltIn returns true for known tags")
    func isBuiltInReturnsTrueForKnown() {
        #expect(TagVocabulary.isBuiltIn("italian") == true)
        #expect(TagVocabulary.isBuiltIn("chicken") == true)
        #expect(TagVocabulary.isBuiltIn("one-pot") == true)
        #expect(TagVocabulary.isBuiltIn("gluten-free") == true)
    }

    @Test("isBuiltIn is case insensitive")
    func isBuiltInCaseInsensitive() {
        #expect(TagVocabulary.isBuiltIn("Italian") == true)
        #expect(TagVocabulary.isBuiltIn("CHICKEN") == true)
    }

    @Test("isBuiltIn returns false for unknown tags")
    func isBuiltInReturnsFalseForUnknown() {
        #expect(TagVocabulary.isBuiltIn("date-night") == false)
        #expect(TagVocabulary.isBuiltIn("kid-friendly") == false)
        #expect(TagVocabulary.isBuiltIn("") == false)
    }

    @Test("category returns correct category for built-in tag")
    func categoryReturnsCorrectCategory() {
        #expect(TagVocabulary.category(for: "italian") == .cuisine)
        #expect(TagVocabulary.category(for: "breakfast") == .meal)
        #expect(TagVocabulary.category(for: "grilled") == .method)
        #expect(TagVocabulary.category(for: "vegan") == .diet)
        #expect(TagVocabulary.category(for: "chicken") == .protein)
    }

    @Test("category returns nil for custom tags")
    func categoryReturnsNilForCustom() {
        #expect(TagVocabulary.category(for: "date-night") == nil)
        #expect(TagVocabulary.category(for: "weeknight") == nil)
    }

    @Test("Each category has expected tag count")
    func categoriesHaveExpectedCounts() {
        #expect(TagVocabulary.Category.cuisine.tags.count == 15)
        #expect(TagVocabulary.Category.meal.tags.count == 7)
        #expect(TagVocabulary.Category.method.tags.count == 8)
        #expect(TagVocabulary.Category.diet.tags.count == 4)
        #expect(TagVocabulary.Category.protein.tags.count == 9)
    }

    @Test("No duplicate tags across categories")
    func noDuplicatesAcrossCategories() {
        var seen = Set<String>()
        for category in TagVocabulary.Category.allCases {
            for tag in category.tags {
                #expect(!seen.contains(tag), "Duplicate tag: \(tag)")
                seen.insert(tag)
            }
        }
    }
}
