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
    
    // Image size limits
    private let maxImageDimension: CGFloat = 2048
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    
    // Published properties for UI updates
    @Published var personImage: UIImage?
    @Published var clothImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var historyItems: [TryOnResult] = []
    
    // Loading states
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Flag for auto-showing result sheet
    @Published var resultProcessed = false
    
    // Alert handling
    @Published var appError: AppError?
    @Published var showingAlert = false
    
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
    init() {
        logger.log("TryOnViewModel initialized")
        Task {
            await loadHistory()
        }
    }
    
    // Load history from service
    func loadHistory() async {
        logger.log("Loading history")
        historyItems = await tryOnService.getHistory()
        logger.log("History loaded: \(self.historyItems.count) items")
    }
    
    // Validate images before processing
    private func validateImages(_ personImage: UIImage, _ clothImage: UIImage) -> Bool {
        logger.log("Validating images - Person: \(personImage.size.width)x\(personImage.size.height), Cloth: \(clothImage.size.width)x\(clothImage.size.height)")
        
        // Check for zero size images
        if personImage.size.width <= 0 || personImage.size.height <= 0 {
            logger.error("Person image has invalid dimensions")
            showError(title: "Invalid Image", message: "The person image has invalid dimensions")
            return false
        }
        
        if clothImage.size.width <= 0 || clothImage.size.height <= 0 {
            logger.error("Clothing image has invalid dimensions")
            showError(title: "Invalid Image", message: "The clothing image has invalid dimensions")
            return false
        }
        
        // Check for extremely large images
        if personImage.size.width > maxImageDimension || personImage.size.height > maxImageDimension {
            logger.warning("Person image is very large: \(personImage.size.width)x\(personImage.size.height)")
        }
        
        if clothImage.size.width > maxImageDimension || clothImage.size.height > maxImageDimension {
            logger.warning("Clothing image is very large: \(clothImage.size.width)x\(clothImage.size.height)")
        }
        
        // Estimate file size (rough approximation)
        let estimatedPersonSize = Int(personImage.size.width * personImage.size.height * 4) // 4 bytes per pixel (RGBA)
        let estimatedClothSize = Int(clothImage.size.width * clothImage.size.height * 4)
        
        logger.log("Estimated sizes - Person: \(estimatedPersonSize/1024) KB, Cloth: \(estimatedClothSize/1024) KB")
        
        if estimatedPersonSize > maxFileSize {
            logger.error("Person image is too large (\(estimatedPersonSize/1024/1024) MB)")
            showError(title: "Image Too Large", message: "The person image is too large. Please select a smaller image.")
            return false
        }
        
        if estimatedClothSize > maxFileSize {
            logger.error("Clothing image is too large (\(estimatedClothSize/1024/1024) MB)")
            showError(title: "Image Too Large", message: "The clothing image is too large. Please select a smaller image.")
            return false
        }
        
        return true
    }
    
    // Try on function
    func tryOnCloth() async {
        logger.log("tryOnCloth called")
        
        guard let personImage = personImage, let clothImage = clothImage else {
            logger.error("Missing images for try-on")
            showError(title: "Missing Images", message: "Please select both a person image and a clothing item")
            return
        }
        
        // Validate images before proceeding
        if !validateImages(personImage, clothImage) {
            return
        }
        
        isLoading = true
        errorMessage = nil
        logger.log("Starting try-on process")
        
        do {
            // Use Task with priority to ensure we don't block the main thread
            let result = try await Task.detached(priority: .userInitiated) {
                return try await self.tryOnService.tryOnCloth(personImage: personImage, clothImage: clothImage)
            }.value
            
            logger.log("Try-on completed successfully")
            resultImage = result.resultImage
            await loadHistory()
            
            // Signal that result processing is complete
            resultProcessed = true
        } catch let error as NetworkError {
            logger.error("Network error during try-on: \(error.localizedDescription)")
            handleNetworkError(error)
        } catch {
            logger.error("Unexpected error during try-on: \(error.localizedDescription)")
            showError(error: error)
        }
        
        isLoading = false
        logger.log("Try-on process finished")
    }
    
    // Handle specific network errors
    private func handleNetworkError(_ error: NetworkError) {
        logger.log("Handling network error: \(error.localizedDescription)")
        switch error {
        case .serverError(let code, let message):
            showError(title: "Server Error (\(code))", message: message)
        case .invalidURL:
            showError(title: "Configuration Error", message: "Invalid API URL. Please check your network settings.")
        case .noData:
            showError(title: "Image Error", message: "Could not process the selected images.")
        case .invalidResponse, .decodingError:
            showError(title: "Processing Error", message: "The server returned an invalid response. Please try again.")
        case .requestFailed(let underlyingError):
            showError(title: "Network Error", message: "Could not communicate with the server: \(underlyingError.localizedDescription)")
        case .timeoutError:
            showError(title: "Timeout Error", message: "The server took too long to respond. Please try again later or with smaller images.")
        case .memoryError:
            showError(title: "Memory Error", message: "Not enough memory to process these images. Try using smaller images or restarting the app.")
        case .imageTooLarge:
            showError(title: "Image Size Error", message: "One or both of your images are too large to process. Please select smaller images or take a new photo with your camera.")
        }
    }
    
    // Show error with custom title and message
    private func showError(title: String = "Error", message: String) {
        logger.error("\(title): \(message)")
        errorMessage = message
        appError = AppError(title: title, message: message)
        showingAlert = true
    }
    
    // Show error from an Error object
    private func showError(error: Error) {
        logger.error("Error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        appError = AppError(error: error)
        showingAlert = true
    }
    
    // Reset selections
    func resetSelections() {
        logger.log("Resetting selections")
        personImage = nil
        clothImage = nil
        resultImage = nil
        errorMessage = nil
    }
    
    // Clear history
    func clearHistory() async {
        logger.log("Clearing history")
        await tryOnService.clearHistory()
        await loadHistory()
    }
    
    // Set person image with validation
    func setPersonImage(_ image: UIImage?) {
        if let image = image {
            logger.log("Setting person image: \(image.size.width)x\(image.size.height)")
            DebugUtils.logImageDetails(image: image, label: "Person")
        } else {
            logger.log("Clearing person image")
        }
        personImage = image
    }
    
    // Set cloth image with validation
    func setClothImage(_ image: UIImage?) {
        if let image = image {
            logger.log("Setting cloth image: \(image.size.width)x\(image.size.height)")
            DebugUtils.logImageDetails(image: image, label: "Clothing")
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
    
    // Monitor for potential issues
    func checkForPerformanceIssues() {
        DebugUtils.logMemoryUsage(tag: "TryOnViewModel")
        let issues = DebugUtils.checkForIssues()
        
        if !issues.isEmpty {
            logger.warning("Performance issues detected: \(issues.joined(separator: ", "))")
        }
    }
    
    // Debug helper for stack overflow issues
    func debugCallStack() {
        logger.log("Capturing call stack for debugging")
        DebugUtils.logCallStack(tag: "TryOnViewModel")
        DebugUtils.clearTemporaryFiles()
    }
} 
