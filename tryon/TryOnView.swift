import SwiftUI

struct TryOnView: View {
    @EnvironmentObject var viewModel: TryOnViewModel
    @State private var showingPersonImagePicker = false
    @State private var showingClothImagePicker = false
    @State private var showingResultSheet = false
    
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
                            showingClothImagePicker = true
                        }
                    }
                    
                    // Result area
                    if viewModel.isLoading {
                        ProgressView("Processing...")
                            .padding()
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
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    // Action buttons side by side
                    HStack(spacing: Constants.spacing) {
                        // Try On button
                        Button {
                            Task {
                                await viewModel.tryOnCloth()
                                // When processing completes, show result sheet
                                if viewModel.resultImage != nil && !viewModel.isLoading {
                                    showingResultSheet = true
                                }
                            }
                        } label: {
                            Text("Try On")
                                .font(.headline)
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
                ImagePicker(image: $viewModel.personImage)
            }
            .sheet(isPresented: $showingClothImagePicker) {
                ImagePicker(image: $viewModel.clothImage)
            }
            .sheet(isPresented: $showingResultSheet) {
                if let resultImage = viewModel.resultImage {
                    ResultSheetView(image: resultImage)
                }
            }
            .onChange(of: viewModel.resultProcessed) { _, newValue in
                if newValue {
                    showingResultSheet = true
                    viewModel.resultProcessed = false
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

#Preview {
    TryOnView()
        .environmentObject(TryOnViewModel())
} 