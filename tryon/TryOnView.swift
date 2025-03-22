import SwiftUI
import os.log

struct TryOnView: View {
    @EnvironmentObject var viewModel: TryOnViewModel
    @EnvironmentObject var globalViewModel: GlobalViewModel  // Keep for subscription status and trial limits
    @State private var showingPersonImagePicker = false
    @State private var showingClothImagePicker = false
    @State private var showingResultSheet = false
    @State private var currentResultId: UUID?
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnView")
    
    // Maximum content width for iPad
    private let maxContentWidth: CGFloat = 650
    
    var body: some View {
        NavigationStack {
            ScrollView {
                // Center the content and limit width for iPad
                VStack {
                    VStack(spacing: Constants.largeSpacing) {
                        // Header with app logo
                        Text("Dresly")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        // Usage info for free users - keep this for subscription status
                        if !globalViewModel.isPro {
                            Button {
                                globalViewModel.isShowingPayWall = true
                            } label: {
                                HStack {
                                    Image(systemName: "figure.wave")
                                        .foregroundColor(.blue)
                                    Text("You have \(globalViewModel.remainingUsesToday) try-ons left today")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                        }
                        
                        // Image selection area
                        VStack(spacing: Constants.largeSpacing) {
                            // Person image selection with history
                            VStack(spacing: Constants.spacing) {
                                Text("Your Photo")
                                    .font(.headline)
                                
                                Text("Select a clear photo of yourself")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                // Horizontal scroll for person photos (including selected image)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Constants.spacing) {
                                        // Add new photo button
                                        Button(action: {
                                            logger.log("Opening person image picker")
                                            showingPersonImagePicker = true
                                        }) {
                                            VStack {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(.accentColor)
                                                    .frame(width: 100, height: 150)
                                                    .background(Color(.tertiarySystemBackground))
                                                    .cornerRadius(Constants.cornerRadius)
                                                
                                                Text("New")
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        
                                        // Current selected image (if any)
                                        if let selectedImage = viewModel.personImage {
                                            Button(action: {
                                                logger.log("Opening person image picker to replace current")
                                                showingPersonImagePicker = true
                                            }) {
                                                VStack {
                                                    Image(uiImage: selectedImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 150)
                                                        .clipped()
                                                        .cornerRadius(Constants.cornerRadius)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                                                .stroke(Color.accentColor, lineWidth: 3)
                                                        )
                                                    
                                                    Text("Current")
                                                        .font(.caption)
                                                        .foregroundColor(.primary)
                                                }
                                            }
                                        }
                                        
                                        // Previous photos from history, not including current
                                        let historyItems = viewModel.historyItems
                                            .filter { item in
                                                
                                                // Skip if it appears to be the current image
                                                if let currentImage = viewModel.personImage {
                                                    // Compare dimensions as a simple way to detect likely duplicates
                                                    let sameSize = (
                                                        abs(item.personImage.size.width - currentImage.size.width) < 1 &&
                                                        abs(item.personImage.size.height - currentImage.size.height) < 1
                                                    )
                                                    
                                                    if sameSize {
                                                        return false
                                                    }
                                                }
                                                
                                                return true
                                            }
                                            .reversed() // Newest first
                                        
                                        // Display history items
                                        ForEach(historyItems, id: \.id) { item in
                                            Button(action: {
                                                logger.log("Selected person image from history")
                                                viewModel.setPersonImage(item.personImage)
                                            }) {
                                                VStack {
                                                    Image(uiImage: item.personImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 150)
                                                        .clipped()
                                                        .cornerRadius(Constants.cornerRadius)
                                                    
                                                    if let index = viewModel.historyItems.firstIndex(where: { $0.id == item.id }) {
                                                        Text("Photo \(index + 1)")
                                                            .font(.caption)
                                                            .foregroundColor(.primary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Constants.cornerRadius)
                            
                            // Cloth image selection
                            selectionCard(
                                title: "Clothing Item",
                                subtitle: "Select a photo of a single clothing item for best results",
                                systemImage: "tshirt.fill",
                                isSelected: viewModel.isClothImageSelected,
                                selectedImage: viewModel.clothImage
                            ) {
                                logger.log("Opening clothing image picker")
                                showingClothImagePicker = true
                            }
                            
                            // Image count selection
    //                        VStack(spacing: Constants.spacing) {
    //                            Text("Generated Images")
    //                                .font(.headline)
    //                            
    //                            Text("Number of results to generate")
    //                                .font(.subheadline)
    //                                .foregroundColor(.secondary)
    //                            
    //                            Stepper("Generate \(viewModel.imageCount) image\(viewModel.imageCount > 1 ? "s" : "")", value: $viewModel.imageCount, in: 1...10)
    //                                .padding()
    //                                .background(Color(.tertiarySystemBackground))
    //                                .cornerRadius(Constants.cornerRadius)
    //                        }
    //                        .padding()
    //                        .background(Color(.secondarySystemBackground))
    //                        .cornerRadius(Constants.cornerRadius)
                        }
                        
                        if !viewModel.resultImages.isEmpty {
                            VStack {
                                Text("Try-On Results")
                                    .font(.headline)
                                
                                // Preview of the first image
                                Image(uiImage: viewModel.resultImage ?? UIImage())
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 400)
                                    .cornerRadius(Constants.cornerRadius)
                                    .padding(.bottom, 8)
                                
                                // If there are multiple images, show an indicator
                                if viewModel.resultImages.count > 1 {
                                    Text("Tap to view all \(viewModel.resultImages.count) results")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Constants.cornerRadius)
                            .onTapGesture {
                                showingResultSheet = true
                            }
                        }
                        
                        // Error message
                        if let errorMessage = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(Constants.cornerRadius)
                            .padding(.horizontal)
                        }
                        
                        // Memory usage tip if we've had errors
                        if viewModel.errorMessage != nil {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Tip: Try using smaller photos or clearing the app from memory if you experience issues.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(Constants.cornerRadius)
                            .padding(.horizontal)
                        }
                        
                        // Action buttons side by side
                        HStack(spacing: Constants.spacing) {
                            // Try On button
                            Button {
                                logger.log("Try On button tapped")
                                
                                // Play haptic feedback
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                
                                if !globalViewModel.isPro && globalViewModel.remainingUsesToday <= 0 {
                                    // Show paywall if out of uses
                                    globalViewModel.isShowingPayWall = true
                                } else {
                                    // Track usage in globalViewModel if not a pro user
                                    if !globalViewModel.isPro {
                                        globalViewModel.dailyUsageCount += 1
                                    }
                                    
                                    Task {
                                        await performTryOn()
                                    }
                                }
                            } label: {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                            .padding(.trailing, 4)
                                    }
                                    Text(viewModel.isLoading ? "Processing..." : "Try On")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(Constants.cornerRadius)
                            }
                            .disabled(!viewModel.canTryOn || viewModel.isLoading )
                            .opacity(viewModel.canTryOn && !viewModel.isLoading  ? 1 : 0.5)
                            
                            // Reset button
                            Button {
                                logger.log("Reset button tapped")
                                viewModel.resetSelections()
                            } label: {
                                Text("Reset")
                                    .font(.headline)
                                    .foregroundColor(Color.accentColor)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                            .stroke(Color.accentColor, lineWidth: 1)
                                    )
                                    .cornerRadius(Constants.cornerRadius)
                            }
                            .disabled(viewModel.isLoading)
                        }
                        .padding(.top, Constants.spacing)
                    }
                    .padding()
                    .frame(maxWidth: maxContentWidth)
                }
                .frame(maxWidth: .infinity) // This ensures content is centered
            }
            .sheet(isPresented: $showingPersonImagePicker) {
                ImagePicker(image: $viewModel.personImage, onError: { errorMessage in
                    logger.error("Person image picker error: \(errorMessage)")
                    viewModel.showError(title: "Image Error", message: errorMessage)
                })
            }
            .sheet(isPresented: $showingClothImagePicker) {
                ImagePicker(image: $viewModel.clothImage, onError: { errorMessage in
                    logger.error("Clothing image picker error: \(errorMessage)")
                    viewModel.showError(title: "Image Error", message: errorMessage)
                })
            }
            .sheet(isPresented: $showingResultSheet) {
                if !viewModel.resultImages.isEmpty {
                    ResultSheetView(images: viewModel.resultImages, resultId: currentResultId ?? UUID())
                        .environmentObject(viewModel)
                }
            }
            .onChange(of: viewModel.resultProcessed) { _, newValue in
                if newValue {
                    logger.log("Result processed, showing result sheet")
                    currentResultId = UUID()
                    showingResultSheet = true
                    viewModel.resultProcessed = false
                }
            }
            .alert(
                viewModel.appError?.title ?? "Error",
                isPresented: $viewModel.showingAlert,
                presenting: viewModel.appError
            ) { _ in
                Button("OK") {
                    // Dismiss the alert
                }
            } message: { error in
                Text(error.message)
            }
            .onAppear {
                logger.log("TryOnView appeared")
                // Load history when view appears
                Task {
                    await viewModel.loadHistory()
                }
            }
            .onDisappear {
                logger.log("TryOnView disappeared")
            }
        }
    }
    
    // Function to perform try-on after usage check
    private func performTryOn() async {
        viewModel.isLoading = true
        await viewModel.tryOnCloth(freeRetry: false)
        viewModel.isLoading = false
        
        if !viewModel.resultImages.isEmpty {
            logger.log("Show result sheet after successful try-on")
            currentResultId = UUID()
            showingResultSheet = true
        }
    }
    
    // Helper function to create a consistent selection card UI
    private func selectionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        isSelected: Bool,
        selectedImage: UIImage?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(Constants.cornerRadius)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        .frame(height: 120)
                }
                
                Text(title)
                    .font(.headline)
                    .padding(.top, 8)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(isSelected ? "Tap to change" : "Tap to select")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(Constants.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    TryOnView()
        .environmentObject(TryOnViewModel())
        .environmentObject(GlobalViewModel())
}
