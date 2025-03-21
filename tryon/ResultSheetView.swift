import SwiftUI
import PhotosUI

struct ResultSheetView: View {
    let image: UIImage
    let resultId: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TryOnViewModel
    @State private var showingSaveSuccess = false
    @State private var userRating: UserRating = .none
    @State private var isRetrying = false
    
    enum UserRating {
        case none, like, dislike
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                
                // Satisfaction question
                if userRating == .none {
                    VStack(spacing: 10) {
                        Text("Are you satisfied with this result?")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            // Thumbs down
                            Button {
                                userRating = .dislike
                                // Play haptic feedback
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.warning)
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
                                userRating = .like
                                // Play success feedback
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
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
                
                // Try Again button (shows up after negative rating)
                if userRating == .dislike {
                    Button {
                        isRetrying = true
                        Task {
                            await retryTryOn()
                        }
                    } label: {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 4)
                            }
                            Text(isRetrying ? "Processing..." : "Try Again")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(Constants.cornerRadius)
                    }
                    .disabled(isRetrying)
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
    
    // Function to retry the try-on without using credits
    private func retryTryOn() async {
        // Set loading state
        isRetrying = true
        
        // Call tryOnCloth without decrementing usage count
        await viewModel.tryOnCloth(freeRetry: true)
        
        // Update UI state
        isRetrying = false
        
        // Close this sheet as the new result will show in a new sheet
        dismiss()
    }
}

#Preview {
    ResultSheetView(image: UIImage(systemName: "person.fill")!, resultId: UUID())
        .environmentObject(TryOnViewModel())
} 