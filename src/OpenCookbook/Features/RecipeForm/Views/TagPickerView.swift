//
//  TagPickerView.swift
//  OpenCookbook
//
//  Tag picker component for the recipe form with category sections and flow layout
//

import SwiftUI

/// Tag picker showing built-in tags grouped by category with chip-style selection
struct TagPickerView: View {
    @Binding var selectedTags: Set<String>
    let tagFrequencies: [TagFrequency]
    @Binding var customTagText: String
    var onAddCustomTag: () -> Void

    @State private var searchText: String = ""

    // MARK: - Computed

    private var frequencyMap: [String: Int] {
        Dictionary(uniqueKeysWithValues: tagFrequencies.map { ($0.name, $0.count) })
    }

    private var customTags: [TagFrequency] {
        tagFrequencies.filter { !$0.isBuiltIn }
    }

    /// Tags from selectedTags that don't appear in tagFrequencies at all (newly added custom tags)
    private var newCustomTags: [String] {
        let knownNames = Set(tagFrequencies.map(\.name))
        return selectedTags.filter { !knownNames.contains($0) }.sorted()
    }

    private var filteredCategories: [(TagVocabulary.Category, [String])] {
        TagVocabulary.Category.allCases.compactMap { category in
            let tags = category.tags.filter { matchesSearch($0) }
            return tags.isEmpty ? nil : (category, tags)
        }
    }

    private var filteredCustomTags: [TagFrequency] {
        customTags.filter { matchesSearch($0.name) }
    }

    private var filteredNewCustomTags: [String] {
        newCustomTags.filter { matchesSearch($0) }
    }

    private func matchesSearch(_ tag: String) -> Bool {
        searchText.isEmpty || tag.localizedCaseInsensitiveContains(searchText)
    }

    // MARK: - Body

    var body: some View {
        Section("Tags") {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter tags", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Selected tags summary
            if !selectedTags.isEmpty {
                selectedTagsSummary
            }

            // Category sections
            ForEach(filteredCategories, id: \.0) { category, tags in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            pickerChip(tag: tag, count: frequencyMap[tag] ?? 0)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Custom tag input
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Add custom tag", text: $customTagText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { onAddCustomTag() }

                    Button {
                        onAddCustomTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(customTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Subviews

    private var selectedTagsSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(selectedTags.sorted(), id: \.self) { tag in
                    Button {
                        selectedTags.remove(tag)
                    } label: {
                        HStack(spacing: 4) {
                            Text(tag)
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pickerChip(tag: String, count: Int) -> some View {
        let isSelected = selectedTags.contains(tag)
        return SelectableChip(
            tag,
            badge: count > 0 ? "\(count)" : nil,
            isSelected: isSelected,
            showCheckmark: true
        ) {
            if isSelected {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        }
        .accessibilityLabel("\(tag)\(count > 0 ? ", \(count) recipes" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview("Tag Picker") {
    @Previewable @State var selectedTags: Set<String> = ["italian", "chicken"]
    @Previewable @State var customTagText: String = ""

    Form {
        TagPickerView(
            selectedTags: $selectedTags,
            tagFrequencies: [
                TagFrequency(name: "italian", count: 12, category: .cuisine),
                TagFrequency(name: "chicken", count: 8, category: .protein),
                TagFrequency(name: "one-pot", count: 5, category: .method),
                TagFrequency(name: "vegetarian", count: 4, category: .diet),
                TagFrequency(name: "main", count: 3, category: .meal),
                TagFrequency(name: "date-night", count: 2, category: nil),
            ],
            customTagText: $customTagText,
            onAddCustomTag: {}
        )
    }
}

#Preview("Empty Tag Picker") {
    @Previewable @State var selectedTags: Set<String> = []
    @Previewable @State var customTagText: String = ""

    Form {
        TagPickerView(
            selectedTags: $selectedTags,
            tagFrequencies: RecipeSearchService.computeTagFrequencies(from: []),
            customTagText: $customTagText,
            onAddCustomTag: {}
        )
    }
}
