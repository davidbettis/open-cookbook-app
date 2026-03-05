//
//  RecipeShareSheet.swift
//  OpenCookbook
//
//  UIActivityViewController wrapper for sharing recipes.
//  Sends readable text to messaging apps, .recipemd file to AirDrop/email.
//

#if canImport(UIKit)
import UIKit
import SwiftUI

/// Activity item source that adapts content per share target:
/// - iMessage / messaging: readable recipe text + promo message
/// - AirDrop / email: .recipemd file attachment
final class RecipeActivitySource: NSObject, UIActivityItemSource {
    let title: String
    let markdown: String
    let fileURL: URL

    private static let promoMessage = "\n\nCheck out Open Cookbook to build a free recipe library.\nhttps://apps.apple.com/app/open-cookbook/id6740043751"

    /// Activity types that work better with inline text than file attachments
    private static let textActivityTypes: Set<UIActivity.ActivityType> = [
        .message,
        .copyToPasteboard,
    ]

    init(title: String, markdown: String) {
        self.title = title
        self.markdown = markdown

        let filename = "\(title).recipemd"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? Data(markdown.utf8).write(to: tmpURL)
        self.fileURL = tmpURL

        super.init()
    }

    // Placeholder: use a string so the system knows we can provide text
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        markdown
    }

    // Return clean recipe text for messaging apps (pasteable into the app), file for everything else
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if let activityType, Self.textActivityTypes.contains(activityType) {
            return markdown
        }
        return fileURL
    }

    // Email subject line
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }
}

/// Provides email body text for email activity types, nil for everything else.
/// Added as a separate activity item so email gets both body text and file attachment.
final class RecipeEmailBodySource: NSObject, UIActivityItemSource {
    private static let bodyText = "Check out this recipe. Build your own recipe library with Open Cookbook.\nhttps://apps.apple.com/app/open-cookbook/id6740043751"

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        ""
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        guard let activityType else { return nil }
        // Provide body text for email-type activities only
        if activityType == .mail || activityType.rawValue.lowercased().contains("mail") {
            return Self.bodyText
        }
        return nil
    }
}

/// UIViewControllerRepresentable wrapper for UIActivityViewController
struct RecipeShareSheet: UIViewControllerRepresentable {
    let title: String
    let markdown: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = RecipeActivitySource(title: title, markdown: markdown)
        let emailBody = RecipeEmailBodySource()
        let controller = UIActivityViewController(
            activityItems: [source, emailBody],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
