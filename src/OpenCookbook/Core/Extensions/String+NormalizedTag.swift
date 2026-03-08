//
//  String+NormalizedTag.swift
//  OpenCookbook
//
//  Consistent tag normalization used throughout the app
//

import Foundation

extension String {
    /// Normalize a tag for storage and comparison: lowercased and trimmed.
    var normalizedTag: String {
        lowercased().trimmingCharacters(in: .whitespaces)
    }
}
