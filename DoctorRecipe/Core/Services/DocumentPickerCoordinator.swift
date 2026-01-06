//
//  DocumentPickerCoordinator.swift
//  DoctorRecipe
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController to select folders
struct FolderPicker: UIViewControllerRepresentable {

    @Binding var selectedURL: URL?
    var onSelect: (URL) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false

        // Start in Documents directory (works locally without iCloud)
        // User can still navigate to iCloud Drive if available
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            picker.directoryURL = documentsURL
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FolderPicker

        init(_ parent: FolderPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource")
                return
            }

            // Note: We'll stop accessing the resource after saving the bookmark
            // The bookmark will allow us to access it again later
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            parent.selectedURL = url
            parent.onSelect(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}
