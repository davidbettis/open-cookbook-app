//
//  RecipeCardSkeleton.swift
//  OpenCookbook
//
//  Skeleton loading state for recipe cards
//

import SwiftUI

/// Skeleton placeholder view shown while recipes are loading
struct RecipeCardSkeleton: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Skeleton title
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
                .frame(maxWidth: 200)

            // Skeleton tag
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 16)

            // Skeleton description
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 14)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview {
    VStack {
        RecipeCardSkeleton()
        RecipeCardSkeleton()
        RecipeCardSkeleton()
    }
    .padding()
}

#Preview("In List") {
    List(0..<5, id: \.self) { _ in
        RecipeCardSkeleton()
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
    .listStyle(.plain)
}
