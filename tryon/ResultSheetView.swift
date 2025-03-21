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
    
    // Maximum content width for iPad
    private let maxContentWidth: CGFloat = 650
    
    var body: some View {
        NavigationStack {
            ScrollView {
                // Center the content and limit width for iPad
                VStack {
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
                        
                        // Disclaimer text
                        Text("Note: The AI model may not always produce perfect results on the first try. Feel free to use the Try Again option for potentially better results.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                    .frame(maxWidth: maxContentWidth)
                }
                .frame(maxWidth: .infinity) // This ensures content is centered
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
        // Track retry attempt
        Plausible.shared.trackEvent(event: "tryon_interaction", path: "/results", properties: [
            "action": "retry",
            "remaining_retries": String(remainingRetries),
            "result_id": resultId.uuidString
        ])
        
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
    
    // Maximum content width for iPad
    private let maxContentWidth: CGFloat = 650
    
    enum UserRating {
        case none, like, dislike
    }
    
    var body: some View {
        ScrollView {
            // Center the content and limit width for iPad
            VStack {
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
                                    // Track dislike
                                    Plausible.shared.trackEvent(event: "tryon_interaction", path: "/results", properties: [
                                        "action": "feedback",
                                        "sentiment": "dislike",
                                        "result_id": resultId.uuidString
                                    ])
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
                                    // Track like
                                    Plausible.shared.trackEvent(event: "tryon_interaction", path: "/results", properties: [
                                        "action": "feedback",
                                        "sentiment": "like",
                                        "result_id": resultId.uuidString
                                    ])
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
                        .simultaneousGesture(TapGesture().onEnded {
                            // Track share attempt
                            Plausible.shared.trackEvent(event: "tryon_interaction", path: "/results", properties: [
                                "action": "share",
                                "result_id": resultId.uuidString
                            ])
                        })
                        
                        // Save to photos button
                        Button {
                            saveImageToPhotoLibrary(image)
                            // Track save to photos
                            Plausible.shared.trackEvent(event: "tryon_interaction", path: "/results", properties: [
                                "action": "save",
                                "result_id": resultId.uuidString
                            ])
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
                .frame(maxWidth: maxContentWidth)
            }
            .frame(maxWidth: .infinity) // This ensures content is centered
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
