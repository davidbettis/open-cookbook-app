//
//  BulkTagRemoveView.swift
//  OpenCookbook
//
//  Sheet for bulk-removing tags from selected recipes
//

import SwiftUI

struct BulkTagRemoveView: View {
    let totalSelected: Int
    let tagsWithCounts: [(tag: String, count: Int)]
    let onApply: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTags: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if tagsWithCounts.isEmpty {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag.slash",
                        description: Text("The selected recipes have no tags to remove.")
                    )
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(tagsWithCounts, id: \.tag) { item in
                            removeChip(tag: item.tag, count: item.count)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Remove Tags from \(totalSelected) Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(selectedTags)
                        dismiss()
                    }
                    .disabled(selectedTags.isEmpty)
                }
            }
        }
    }

    private func removeChip(tag: String, count: Int) -> some View {
        let isSelected = selectedTags.contains(tag)
        return Button {
            if isSelected {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text("\(tag) (\(count) of \(totalSelected))")
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
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
        .accessibilityLabel("\(tag), \(count) of \(totalSelected) selected recipes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview {
    BulkTagRemoveView(
        totalSelected: 5,
        tagsWithCounts: [
            (tag: "italian", count: 3),
            (tag: "dinner", count: 5),
            (tag: "chicken", count: 2),
            (tag: "baked", count: 1),
            (tag: "date-night", count: 1)
        ],
        onApply: { _ in }
    )
}
