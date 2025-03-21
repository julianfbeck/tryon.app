import SwiftUI
import os.log

struct TryOnView: View {
    @EnvironmentObject var viewModel: TryOnViewModel
    @EnvironmentObject var globalViewModel: GlobalViewModel
    @State private var showingPersonImagePicker = false
    @State private var showingClothImagePicker = false
    @State private var showingResultSheet = false
    @State private var showingSatisfactionDialog = false
    @State private var currentResultId: UUID?
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnView")
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.largeSpacing) {
                    // Header with app logo
                    Text("Virtual Try-On")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Usage info for free users
                    if !globalViewModel.isPro {
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
                                    
                                    // Previous photos from history (newest first)
                                    ForEach(viewModel.historyItems.filter {
                                        $0.personImage != nil &&
                                        $0.personImage.pngData() != viewModel.personImage?.pngData()
                                    }.reversed(), id: \.id) { item in
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
                                                
                                                Text("Photo \(viewModel.historyItems.firstIndex(where: { $0.id == item.id })?.advanced(by: 1) ?? 0)")
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
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
                            subtitle: "Select a clothing item to try on",
                            systemImage: "tshirt.fill",
                            isSelected: viewModel.isClothImageSelected,
                            selectedImage: viewModel.clothImage
                        ) {
                            logger.log("Opening clothing image picker")
                            showingClothImagePicker = true
                        }
                    }
                    
                 let resultImage = viewModel.resultImage {
                        VStack {
                            Text("Try-On Result")
                                .font(.headline)
                            
                            Image(uiImage: resultImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 400)
                                .cornerRadius(Constants.cornerRadius)
                                .onTapGesture {
                                    showingResultSheet = true
                                }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(Constants.cornerRadius)
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
                            
                            // Check if user can use feature
                            if globalViewModel.useFeature() {
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
                        .disabled(!viewModel.canTryOn || viewModel.isLoading)
                        .opacity(viewModel.canTryOn && !viewModel.isLoading ? 1 : 0.5)
                        
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
                if let resultImage = viewModel.resultImage, let lastResult = viewModel.historyItems.first {
                    ResultSheetView(image: resultImage, resultId: lastResult.id)
                }
            }
            .onChange(of: viewModel.resultProcessed) { _, newValue in
                if newValue {
                    logger.log("Result processed, showing result sheet")
                    showingResultSheet = true
                    viewModel.resultProcessed = false
                }
            }
            .fullScreenCover(isPresented: $globalViewModel.isShowingPayWall) {
                PayWallView()
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
        await viewModel.tryOnCloth()
        if viewModel.resultImage != nil && !viewModel.isLoading {
            logger.log("Show result sheet after successful try-on")
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
