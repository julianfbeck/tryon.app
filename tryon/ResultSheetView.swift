import SwiftUI
import PhotosUI

struct ResultSheetView: View {
    let image: UIImage
    let resultId: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var globalViewModel: GlobalViewModel
    @State private var showingSaveSuccess = false
    @State private var hasRated = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                
                // Satisfaction question
                if !hasRated {
                    VStack(spacing: 10) {
                        Text("Are you satisfied with this result?")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            // Thumbs down
                            Button {
                                globalViewModel.recordSentiment(rating: 2, for: resultId)
                                hasRated = true
                            } label: {
                                VStack {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.red)
                                    Text("No")
                                        .font(.caption)
                                }
                                .frame(width: 60)
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                            }
                            
                            // Thumbs up
                            Button {
                                globalViewModel.recordSentiment(rating: 4, for: resultId)
                                hasRated = true
                            } label: {
                                VStack {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.green)
                                    Text("Yes")
                                        .font(.caption)
                                }
                                .frame(width: 60)
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(Constants.cornerRadius)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
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
    ResultSheetView(image: UIImage(systemName: "person.fill")!, resultId: UUID())
        .environmentObject(GlobalViewModel())
} 