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

            // Custom tags section
            if !filteredCustomTags.isEmpty || !filteredNewCustomTags.isEmpty || searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if !filteredCustomTags.isEmpty || !filteredNewCustomTags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(filteredCustomTags) { freq in
                                pickerChip(tag: freq.name, count: freq.count)
                            }
                            ForEach(filteredNewCustomTags, id: \.self) { tag in
                                pickerChip(tag: tag, count: 0)
                            }
                        }
                    }

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
                    .padding(.top, 8)
                }
                .padding(.vertical, 4)
            }
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
                Text(tag)
                if count > 0 {
                    Text("\(count)")
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
        .accessibilityLabel("\(tag)\(count > 0 ? ", \(count) recipes" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - FlowLayout

/// A simple wrapping flow layout using the SwiftUI Layout protocol
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                // Wrap to next row
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }

        return ArrangeResult(positions: positions, size: CGSize(width: totalWidth, height: totalHeight))
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
