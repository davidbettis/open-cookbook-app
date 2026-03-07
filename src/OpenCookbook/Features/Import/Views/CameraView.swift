//
//  CameraView.swift
//  OpenCookbook
//
//  Multi-capture camera: after each photo, offers "Take Another" or "Done"
//

#if canImport(UIKit)
import SwiftUI
import UIKit

struct CameraView: View {
    var maxPhotos: Int
    var onPhotoCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var lastPhoto: UIImage?
    @State private var cameraID = UUID()
    @State private var photosTaken = 0

    private var canTakeMore: Bool { photosTaken < maxPhotos }

    var body: some View {
        ZStack {
            if lastPhoto == nil {
                CameraPicker(onCapture: { image in
                    lastPhoto = image
                }, onCancel: {
                    dismiss()
                })
                .id(cameraID)
                .ignoresSafeArea()
            } else if let photo = lastPhoto {
                photoReviewView(photo)
            }
        }
    }

    private func photoReviewView(_ photo: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Spacer()

                HStack(spacing: 16) {
                    if canTakeMore {
                        Button {
                            onPhotoCaptured(photo)
                            photosTaken += 1
                            lastPhoto = nil
                            cameraID = UUID()
                        } label: {
                            Label("Take Another", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }

                    Button {
                        onPhotoCaptured(photo)
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }
}

/// Thin UIImagePickerController wrapper — captures a single photo and calls back.
private struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
#endif
