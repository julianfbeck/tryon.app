import SwiftUI
import PhotosUI

struct ResultSheetView: View {
    let images: [UIImage]
    let resultId: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TryOnViewModel
    @State private var isRetrying = false
    @State private var selectedImageIndex = 0
    @State private var showDetailView = false
    @State private var remainingRetries = 1
    
    // Grid layout columns
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header text
                    Text("Choose your favorite result")
                        .font(.headline)
                        .padding(.top)
                    
                    // Grid of images
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<images.count, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: images[index])
                                    .resizable()
                                    .scaledToFill() // Fill the frame
                                    .frame(width: UIScreen.main.bounds.width / 2.3, height: UIScreen.main.bounds.width / 2.3) // Square frame
                                    .clipped() // Clip any overflow
                                    .cornerRadius(Constants.cornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                            .stroke(index == selectedImageIndex ? Color.accentColor : Color.clear, lineWidth: 3)
                                    )
                                    .onTapGesture {
                                        selectedImageIndex = index
                                    }
                                
                                // Selection checkmark
                                if index == selectedImageIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.accentColor)
                                        .background(Circle().fill(Color.white))
                                        .padding(8)
                                }
                            }
                            .padding(4) // Add padding around each item
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action buttons (using the same style as TryOnView)
                    HStack(spacing: 12) {
                        // Select button (primary style)
                        NavigationLink {
                            ResultDetailView(
                                image: images[selectedImageIndex],
                                resultId: resultId,
                                personImage: viewModel.personImage ?? UIImage(),
                                clothImage: viewModel.clothImage ?? UIImage()
                            )
                            .environmentObject(viewModel)
                        } label: {
                            Text("Select")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(Constants.cornerRadius)
                        }
                        
                        // Try Again button (outline style)
                        Button {
                            isRetrying = true
                            Task {
                                await retryTryOn()
                            }
                        } label: {
                            HStack {
                                if isRetrying {
                                    ProgressView()
                                        .tint(Color.accentColor)
                                        .padding(.trailing, 4)
                                }
                                Text(isRetrying ? "Processing..." : "Try Again")
                                    .font(.headline)
                                if !isRetrying {
                                    Text("(\(remainingRetries)/1)")
                                        .font(.subheadline)
                                        .foregroundColor(remainingRetries > 0 ? .accentColor : .secondary)
                                }
                            }
                            .foregroundColor(remainingRetries > 0 ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                    .stroke(remainingRetries > 0 ? Color.accentColor : Color.secondary, lineWidth: 1)
                            )
                            .cornerRadius(Constants.cornerRadius)
                        }
                        .disabled(isRetrying || remainingRetries == 0)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .padding(.bottom)
            }
            .navigationTitle("Try-On Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Function to retry the try-on without using credits
    private func retryTryOn() async {
        // Set loading state
        isRetrying = true
        
        // Decrement remaining retries
        remainingRetries -= 1
        
        // Call tryOnCloth without decrementing usage count
        await viewModel.tryOnCloth(freeRetry: true, resultId: resultId)
        
        // Update UI state
        isRetrying = false
        
        // Close this sheet as the new result will show in a new sheet
        dismiss()
    }
}

// Second screen showing the detail view of the selected image
struct ResultDetailView: View {
    let image: UIImage
    let resultId: UUID
    let personImage: UIImage
    let clothImage: UIImage
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TryOnViewModel
    @State private var showingSaveSuccess = false
    @State private var userRating: UserRating = .none
    @State private var hasSavedToHistory = false
    
    enum UserRating {
        case none, like, dislike
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Selected image (large view)
                VStack(spacing: 8) {
                    Text("Selected Image")
                        .font(.headline)
                        .padding(.top)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(Constants.cornerRadius)
                        .padding(.horizontal)
                }
                
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
                                }
                                .frame(width: 60)
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
                
                // Action buttons for sharing and saving
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
                        saveImageToPhotoLibrary(image)
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
            }
            .padding(.bottom)
        }
        .navigationTitle("Selected Result")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Image Saved", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The image has been saved to your photo library.")
        }
        .onAppear {
            if !hasSavedToHistory {
                Task {
                    await viewModel.saveSelectedImage(index: viewModel.selectedResultIndex)
                    hasSavedToHistory = true
                }
            }
        }
    }
    
    // Function to save an image to the photo library
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showingSaveSuccess = true
    }
}

#Preview {
    ResultSheetView(
        images: [UIImage(systemName: "person.fill")!, UIImage(systemName: "person.crop.square")!],
        resultId: UUID()
    )
    .environmentObject(TryOnViewModel())
} 
