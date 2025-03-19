import SwiftUI
import os.log

struct TryOnView: View {
    @EnvironmentObject var viewModel: TryOnViewModel
    @State private var showingPersonImagePicker = false
    @State private var showingClothImagePicker = false
    @State private var showingResultSheet = false
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnView")
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.largeSpacing) {
                    // Header with app logo
                    Text("Virtual Try-On")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Image selection area
                    VStack(spacing: Constants.largeSpacing) {
                        // Person image selection
                        selectionCard(
                            title: "Your Photo",
                            subtitle: "Select a clear photo of yourself",
                            systemImage: "person.fill",
                            isSelected: viewModel.isPersonImageSelected,
                            selectedImage: viewModel.personImage
                        ) {
                            logger.log("Opening person image picker")
                            showingPersonImagePicker = true
                        }
                        
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
                    
                    // Result area
                    if viewModel.isLoading {
                        VStack {
                            ProgressView()
                                .padding()
                            Text("Processing your try-on request...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 200)
                    } else if let resultImage = viewModel.resultImage {
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
                            Task {
                                await viewModel.tryOnCloth()
                                if viewModel.resultImage != nil && !viewModel.isLoading {
                                    logger.log("Show result sheet after successful try-on")
                                    showingResultSheet = true
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
            .navigationTitle("Try On")
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
                if let resultImage = viewModel.resultImage {
                    ResultSheetView(image: resultImage)
                }
            }
            .onChange(of: viewModel.resultProcessed) { _, newValue in
                if newValue {
                    logger.log("Result processed, showing result sheet")
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
            }
            .onDisappear {
                logger.log("TryOnView disappeared")
            }
            // Special debug button that will appear only if there are errors
            .overlay(alignment: .bottomTrailing) {
                if viewModel.errorMessage != nil {
                    Button {
                        logger.log("Debug button tapped")
                        viewModel.debugCallStack()
                        viewModel.checkForPerformanceIssues()
                    } label: {
                        Image(systemName: "ladybug")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.gray.opacity(0.8)))
                            .padding(16)
                    }
                }
            }
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

extension TryOnViewModel {
    // Add a public function for showing errors from the view
    func showError(title: String, message: String) {
        errorMessage = message
        appError = AppError(title: title, message: message)
        showingAlert = true
    }
}

#Preview {
    TryOnView()
        .environmentObject(TryOnViewModel())
} 