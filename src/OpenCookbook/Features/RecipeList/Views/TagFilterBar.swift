//
//  TagFilterBar.swift
//  OpenCookbook
//
//  Horizontal scrolling tag filter bar
//

import SwiftUI

/// Horizontal scrolling bar of tag filter chips
struct TagFilterBar: View {

    // MARK: - Properties

    let tags: [TagInfo]
    let selectedTags: Set<String>
    var onTagTap: (String) -> Void
    var onClearAll: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Clear all button (shown when tags are selected)
                if !selectedTags.isEmpty {
                    Button {
                        onClearAll()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                            Text("Clear")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear all tag filters")
                }

                // Tag chips
                ForEach(tags) { tagInfo in
                    TagChip(
                        tagInfo: tagInfo,
                        isSelected: selectedTags.contains(tagInfo.name),
                        onTap: { onTagTap(tagInfo.name) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

/// Individual tag chip button
struct TagChip: View {

    // MARK: - Properties

    let tagInfo: TagInfo
    let isSelected: Bool
    var onTap: () -> Void

    // MARK: - Body

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                Text(tagInfo.name)
                Text("\(tagInfo.count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.3)
                            : Color(.systemGray4)
                    )
                    .clipShape(Capsule())
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color(.systemGray4),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tagInfo.name), \(tagInfo.count) recipes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview("With Tags") {
    TagFilterBar(
        tags: [
            TagInfo(name: "dessert", count: 12),
            TagInfo(name: "quick", count: 8),
            TagInfo(name: "vegetarian", count: 5),
            TagInfo(name: "italian", count: 7),
            TagInfo(name: "breakfast", count: 4)
        ],
        selectedTags: ["quick"],
        onTagTap: { _ in },
        onClearAll: {}
    )
}

#Preview("No Selection") {
    TagFilterBar(
        tags: [
            TagInfo(name: "dessert", count: 12),
            TagInfo(name: "quick", count: 8),
            TagInfo(name: "vegetarian", count: 5)
        ],
        selectedTags: [],
        onTagTap: { _ in },
        onClearAll: {}
    )
}

#Preview("Multiple Selected") {
    TagFilterBar(
        tags: [
            TagInfo(name: "dessert", count: 12),
            TagInfo(name: "quick", count: 8),
            TagInfo(name: "vegetarian", count: 5)
        ],
        selectedTags: ["dessert", "quick"],
        onTagTap: { _ in },
        onClearAll: {}
    )
}
