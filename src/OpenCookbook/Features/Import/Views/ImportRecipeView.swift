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

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ImportRecipeViewModel()
    @State private var showError = false
    @State private var errorMessage = ""

    // Photo state
    @State private var selectedImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await loadPhoto(from: newItem) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedImage) { _, newImage in
                processSelectedImage(newImage)
            }
            .onAppear {
                viewModel.source = initialSource
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
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                #if !targetEnvironment(simulator)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(
                            selectedImage == nil ? "Take Photo" : "Retake",
                            systemImage: "camera"
                        )
                    }
                    .buttonStyle(.bordered)
                }
                #endif

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Label(
                        selectedImage == nil ? "Photo Library" : "Choose Different",
                        systemImage: "photo.on.rectangle"
                    )
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                Task { await viewModel.importRecipe() }
            } label: {
                Text("Import Recipe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImage == nil || viewModel.isImporting)
        } header: {
            Text("Take a photo of a recipe or choose one from your library.")
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

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
        }
    }

    private func processSelectedImage(_ image: UIImage?) {
        guard let image else {
            viewModel.selectedImageData = nil
            return
        }
        if let data = ImportRecipeViewModel.resizeImageIfNeeded(image) {
            viewModel.selectedImageData = data
            viewModel.selectedImageMediaType = "image/jpeg"
        }
    }
}
