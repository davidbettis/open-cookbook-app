//
//  ImportRecipeView.swift
//  OpenCookbook
//
//  Import sheet for importing recipes from websites or photos via Claude
//

import PhotosUI
import SwiftUI

extension Notification.Name {
    static let importRecipeCompleted = Notification.Name("importRecipeCompleted")
}

struct ImportRecipeView: View {
    var initialSource: ImportRecipeViewModel.ImportSource = .website
    var tagPrompt: String = ""

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ImportRecipeViewModel()
    @State private var showError = false
    @State private var errorMessage = ""

    // Photo state
    @State private var selectedUIImages: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.hasAPIKey {
                    noAPIKeySection
                } else {
                    switch viewModel.source {
                    case .website:
                        urlInputSection
                    case .photo:
                        photoInputSection
                    }

                    if viewModel.isImporting {
                        loadingSection
                    }
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("Try Again") { viewModel.state = .idle }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: viewModel.state) { _, newState in
                switch newState {
                case .success(let markdown):
                    NotificationCenter.default.post(
                        name: .importRecipeCompleted,
                        object: nil,
                        userInfo: ["markdown": markdown]
                    )
                    dismiss()
                case .error(let message):
                    errorMessage = message
                    showError = true
                default:
                    break
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task { await loadPhotos(from: newItems) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                let remaining = ImportRecipeViewModel.maxPhotos - selectedUIImages.count
                CameraView(
                    maxPhotos: remaining,
                    onPhotoCaptured: { image in
                        selectedUIImages.append(image)
                        viewModel.addImage(image)
                    }
                )
                .ignoresSafeArea()
            }
            .onAppear {
                viewModel.source = initialSource
                viewModel.tagPrompt = tagPrompt
            }
        }
    }

    // MARK: - Sections

    private var noAPIKeySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "key")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Set up your API key in Settings to import recipes.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private var urlInputSection: some View {
        Section {
            TextField("Paste recipe URL here", text: $viewModel.urlText)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                Task { await viewModel.importRecipe() }
            } label: {
                Text("Import Recipe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.urlText.isEmpty || viewModel.isImporting)
        } header: {
            Text("Paste a recipe URL and Claude will extract the recipe for you.")
        }
    }

    private var photoInputSection: some View {
        Section {
            if !selectedUIImages.isEmpty {
                photoThumbnailRow
            }

            HStack {
                #if !targetEnvironment(simulator)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canAddMorePhotos || viewModel.isImporting)
                }
                #endif

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: max(1, ImportRecipeViewModel.maxPhotos - selectedUIImages.count),
                    matching: .images
                ) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canAddMorePhotos || viewModel.isImporting)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                Task { await viewModel.importRecipe() }
            } label: {
                Text("Import Recipe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedUIImages.isEmpty || viewModel.isImporting)
        } header: {
            Text("Take photos of a recipe or choose from your library. Select multiple photos for multi-page recipes.")
        }
    }

    private var photoThumbnailRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedUIImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            removePhoto(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Photo Handling

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedUIImages.append(image)
                viewModel.addImage(image)
            }
        }
        selectedPhotoItems = []
    }

    private func removePhoto(at index: Int) {
        guard selectedUIImages.indices.contains(index) else { return }
        selectedUIImages.remove(at: index)
        viewModel.removeImage(at: index)
    }
}
