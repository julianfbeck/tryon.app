import Foundation
import SwiftUI
import os.log

// Error model for the view model
struct AppError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    
    init(title: String = "Error", message: String) {
        self.title = title
        self.message = message
    }
    
    init(error: Error) {
        self.title = "Error"
        if let networkError = error as? NetworkError {
            self.message = networkError.localizedDescription
        } else {
            self.message = error.localizedDescription
        }
    }
}

// View model acting as a bridge between our views and the TryOnService actor
@MainActor
class TryOnViewModel: ObservableObject {
    // Services
    private let tryOnService = TryOnService()
    
    // Logger instance
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnViewModel")
    
    // Configuration for number of images to generate
    private let defaultImageCount = 4
    @Published var imageCount: Int = 4
    
    // Published properties for UI updates
    @Published var personImage: UIImage?
    @Published var clothImage: UIImage?
    @Published var resultImages: [UIImage] = []
    @Published var selectedResultIndex: Int = 0
    @Published var historyItems: [TryOnResult] = []
    
    // Loading states
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Flag for auto-showing result sheet
    @Published var resultProcessed = false
    
    // Alert handling
    @Published var appError: AppError?
    @Published var showingAlert = false
    
    // Computed property for backward compatibility
    var resultImage: UIImage? {
        resultImages.isEmpty ? nil : resultImages[selectedResultIndex]
    }
    
    // Selection status
    var isPersonImageSelected: Bool {
        personImage != nil
    }
    
    var isClothImageSelected: Bool {
        clothImage != nil
    }
    
    var canTryOn: Bool {
        isPersonImageSelected && isClothImageSelected
    }
    
    // Init
    init(imageCount: Int = 4) {
        logger.log("TryOnViewModel initialized with imageCount: \(imageCount)")
        self.imageCount = imageCount
        Task {
            await loadHistory()
        }
    }
    
    // Configure the number of images to generate
    func setImageCount(_ count: Int) {
        guard count > 0 else {
            logger.error("Invalid image count: \(count), must be > 0")
            return
        }
        logger.log("Setting image count to: \(count)")
        imageCount = count
    }
    
    // Load history from service
    func loadHistory() async {
        logger.log("Loading history")
        historyItems = await tryOnService.getHistory()
        logger.log("History loaded: \(self.historyItems.count) items")
    }
    
    // Try on function
    func tryOnCloth(freeRetry: Bool = false, resultId: UUID? = nil) async {
        logger.log("tryOnCloth called with freeRetry: \(freeRetry)")
        
        guard let personImage = personImage, let clothImage = clothImage else {
            logger.error("Missing images for try-on")
            showError(message: "Please select both a person image and a clothing item")
            return
        }
        
        isLoading = true
        errorMessage = nil
        logger.log("Starting try-on process with \(self.imageCount) images")
        
        do {
            let result = try await tryOnService.tryOnCloth(
                personImage: personImage, 
                clothImage: clothImage,
                isFreeRetry: freeRetry,
                imageCount: imageCount,
                resultId: resultId
            )
            resultImages = result.resultImages
            selectedResultIndex = 0
            // We no longer immediately save to history here - instead wait for user selection
            resultProcessed = true
        } catch {
            showError(error: error)
        }
        
        isLoading = false
        logger.log("Try-on process finished")
    }
    
    // Save the selected image to history
    func saveSelectedImage(index: Int) async {
        logger.log("Saving selected image at index \(index) to history")
        
        guard index >= 0 && index < resultImages.count else {
            logger.error("Invalid index for saving image: \(index)")
            return
        }
        
        guard let personImage = personImage, let clothImage = clothImage else {
            logger.error("Missing person or clothing image when saving selected result")
            return
        }
        
        // Get the selected image
        let selectedImage = resultImages[index]
        
        // Create result with only the selected image
        let result = try? await tryOnService.saveSelectedResult(
            personImage: personImage,
            clothImage: clothImage,
            selectedImage: selectedImage
        )
        
        // Reload history to show the new item
        await loadHistory()
        
        logger.log("Selected image saved to history")
    }
    
    func showError(title: String = "Error", message: String) {
        logger.error("\(title): \(message)")
        errorMessage = message
        appError = AppError(title: title, message: message)
        showingAlert = true
    }
    
    func showError(error: Error) {
        appError = AppError(error: error)
        showingAlert = true
    }
    
    // Reset selections
    func resetSelections() {
        logger.log("Resetting selections")
        personImage = nil
        clothImage = nil
        resultImages = []
        selectedResultIndex = 0
        errorMessage = nil
    }
    
    // Clear history
    func clearHistory() async {
        logger.log("Clearing history")
        await tryOnService.clearHistory()
        await loadHistory()
    }
    
    // Select a specific result image by index
    func selectResultImage(atIndex index: Int) {
        guard index >= 0 && index < resultImages.count else {
            logger.error("Invalid result image index: \(index)")
            return
        }
        logger.log("Selected result image at index: \(index)")
        selectedResultIndex = index
    }
    
    // Set person image with validation
    func setPersonImage(_ image: UIImage?) {
        if let image = image {
            logger.log("Setting person image: \(image.size.width)x\(image.size.height)")
        } else {
            logger.log("Clearing person image")
        }
        personImage = image
    }
    
    // Set cloth image with validation
    func setClothImage(_ image: UIImage?) {
        if let image = image {
            logger.log("Setting cloth image: \(image.size.width)x\(image.size.height)")
        } else {
            logger.log("Clearing cloth image")
        }
        clothImage = image
    }
    
    // Format date for display
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 
