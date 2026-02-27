//
//  BulkTagAddView.swift
//  OpenCookbook
//
//  Sheet for bulk-adding tags to selected recipes
//

import SwiftUI

struct BulkTagAddView: View {
    let selectedCount: Int
    let tagFrequencies: [TagFrequency]
    let onApply: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTags: Set<String> = []
    @State private var customTagText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TagPickerView(
                    selectedTags: $selectedTags,
                    tagFrequencies: tagFrequencies,
                    customTagText: $customTagText,
                    onAddCustomTag: addCustomTag
                )
            }
            .navigationTitle("Add Tags to \(selectedCount) Recipes")
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

    private func addCustomTag() {
        let tag = customTagText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tag.isEmpty else { return }
        selectedTags.insert(tag)
        customTagText = ""
    }
}

// MARK: - Previews

#Preview {
    BulkTagAddView(
        selectedCount: 5,
        tagFrequencies: RecipeSearchService.computeTagFrequencies(from: []),
        onApply: { _ in }
    )
}
