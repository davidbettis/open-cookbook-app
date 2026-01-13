//
//  String+Slug.swift
//  RecipeFree
//
//  String extension for creating URL-safe slugs
//

import Foundation

extension String {

    /// Convert string to URL-safe slug
    /// - Example: "Mom's \"Special\" Cookies!" → "moms-special-cookies"
    var slugified: String {
        // Lowercase
        var slug = self.lowercased()

        // Replace common characters
        slug = slug.replacingOccurrences(of: "'", with: "")
        slug = slug.replacingOccurrences(of: "\"", with: "")

        // Replace spaces and underscores with hyphens
        slug = slug.replacingOccurrences(of: " ", with: "-")
        slug = slug.replacingOccurrences(of: "_", with: "-")

        // Remove any character that isn't alphanumeric or hyphen
        slug = slug.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "-"
        }.map { String($0) }.joined()

        // Replace multiple consecutive hyphens with single hyphen
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }

        // Trim hyphens from start and end
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return slug
    }
}
