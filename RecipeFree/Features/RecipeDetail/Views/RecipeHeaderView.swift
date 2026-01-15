//
//  RecipeHeaderView.swift
//  RecipeFree
//
//  Displays recipe header content (title, description, tags, yields)
//

import RecipeMD
import SwiftUI

/// Displays recipe header content (title, description, tags, yields)
struct RecipeHeaderView: View {
    let title: String
    let description: String?
    let tags: [String]
    let yield: Yield
    var portionMultiplier: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            // Description
            if let description = description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            // Tags
            if !tags.isEmpty {
                TagsView(tags: tags)
            }

            // Yields (scaled by portion multiplier)
            let scaledYield = yield.formattedScaled(by: portionMultiplier)
            if !scaledYield.isEmpty {
                YieldView(yieldText: scaledYield)
            }
        }
    }
}

// MARK: - Tags View

/// Displays tags as styled pills/chips
private struct TagsView: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tags: \(tags.joined(separator: ", "))")
    }
}

// MARK: - Yield View

/// Displays yield information prominently
private struct YieldView: View {
    let yieldText: String

    var body: some View {
        Text(yieldText)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Yield: \(yieldText)")
    }
}

// MARK: - Flow Layout

/// A simple flow layout for wrapping tags
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        let totalWidth = maxWidth.isFinite ? maxWidth : currentX - spacing

        return LayoutResult(
            positions: positions,
            size: CGSize(width: max(0, totalWidth), height: max(0, totalHeight))
        )
    }

    private struct LayoutResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}

// MARK: - Previews

#Preview("Full Header") {
    RecipeHeaderView(
        title: "Chocolate Chip Cookies",
        description: "Classic homemade chocolate chip cookies with a chewy center and crispy edges.",
        tags: ["dessert", "baking", "quick", "family favorite"],
        yield: Yield(amount: [Amount(24, unit: "cookies")])
    )
    .padding()
}

#Preview("Minimal Header") {
    RecipeHeaderView(
        title: "Simple Toast",
        description: nil,
        tags: [],
        yield: Yield(amount: [])
    )
    .padding()
}

#Preview("No Description") {
    RecipeHeaderView(
        title: "Quick Pasta",
        description: nil,
        tags: ["dinner", "quick"],
        yield: Yield(amount: [Amount(4, unit: "servings")])
    )
    .padding()
}
