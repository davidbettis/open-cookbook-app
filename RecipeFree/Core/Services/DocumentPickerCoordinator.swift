//
//  DocumentPickerCoordinator.swift
//  RecipeFree
//
//  Created by Claude Code on 1/6/26.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
/// macOS folder picker using NSOpenPanel
struct FolderPicker: View {
    @Binding var selectedURL: URL?
    var onSelect: (URL) -> Void
    var onCancel: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                showOpenPanel()
            }
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder for your recipes"

        // Start in iCloud Drive if available, otherwise Documents
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            panel.directoryURL = iCloudURL
        } else if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            panel.directoryURL = documentsURL
        }

        let response = panel.runModal()

        if response == .OK, let url = panel.url {
            // Start accessing security-scoped resource
            // Note: This may return false if the URL doesn't require security scoping,
            // so we continue regardless. We only call stop if we successfully started.
            let didStartAccess = url.startAccessingSecurityScopedResource()

            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            selectedURL = url
            onSelect(url)
        } else {
            onCancel()
        }
    }
}
#else
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
            // Note: This may return false if the URL doesn't require security scoping,
            // so we continue regardless. We only call stop if we successfully started.
            let didStartAccess = url.startAccessingSecurityScopedResource()

            // Ensure we stop accessing when done (only if we started)
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            parent.selectedURL = url
            parent.onSelect(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}
#endif
