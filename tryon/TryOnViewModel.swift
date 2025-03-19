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
    
    // Try on function
    func tryOnCloth() async {
        logger.log("tryOnCloth called")
        
        guard let personImage = personImage, let clothImage = clothImage else {
            logger.error("Missing images for try-on")
            showError(message: "Please select both a person image and a clothing item")
            return
        }
        
        isLoading = true
        errorMessage = nil
        logger.log("Starting try-on process")
        
        do {
            let result = try await tryOnService.tryOnCloth(personImage: personImage, clothImage: clothImage)
            resultImage = result.resultImage
            await loadHistory()
            resultProcessed = true
        } catch {
            showError(error: error)
        }
        
        isLoading = false
        logger.log("Try-on process finished")
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
