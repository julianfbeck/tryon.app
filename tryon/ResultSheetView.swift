import SwiftUI
import PhotosUI

struct ResultSheetView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                
                Text("Your Try-On Result")
                    .font(.headline)
                    .padding(.bottom)
                
                HStack(spacing: 20) {
                    // Share button
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("Try-On Result", image: Image(uiImage: image))) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 24))
                            Text("Share")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(Constants.cornerRadius)
                    }
                    
                    // Save to photos button
                    Button {
                        saveImageToPhotoLibrary()
                    } label: {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24))
                            Text("Save")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(Constants.cornerRadius)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Try-On Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Image Saved", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The image has been saved to your photo library.")
            }
        }
    }
    
    // Function to save the image to the photo library
    private func saveImageToPhotoLibrary() {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showingSaveSuccess = true
    }
}

#Preview {
    ResultSheetView(image: UIImage(systemName: "person.fill")!)
} 