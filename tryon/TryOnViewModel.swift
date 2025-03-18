import Foundation
import SwiftUI

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
        Task {
            await loadHistory()
        }
    }
    
    // Load history from service
    func loadHistory() async {
        historyItems = await tryOnService.getHistory()
    }
    
    // Try on function
    func tryOnCloth() async {
        guard let personImage = personImage, let clothImage = clothImage else {
            showError(title: "Missing Images", message: "Please select both a person image and a clothing item")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await tryOnService.tryOnCloth(personImage: personImage, clothImage: clothImage)
            resultImage = result.resultImage
            await loadHistory()
            
            // Signal that result processing is complete
            resultProcessed = true
        } catch let error as NetworkError {
            handleNetworkError(error)
        } catch {
            showError(error: error)
        }
        
        isLoading = false
    }
    
    // Handle specific network errors
    private func handleNetworkError(_ error: NetworkError) {
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
        }
    }
    
    // Show error with custom title and message
    private func showError(title: String = "Error", message: String) {
        errorMessage = message
        appError = AppError(title: title, message: message)
        showingAlert = true
    }
    
    // Show error from an Error object
    private func showError(error: Error) {
        errorMessage = error.localizedDescription
        appError = AppError(error: error)
        showingAlert = true
    }
    
    // Reset selections
    func resetSelections() {
        personImage = nil
        clothImage = nil
        resultImage = nil
        errorMessage = nil
    }
    
    // Clear history
    func clearHistory() async {
        await tryOnService.clearHistory()
        await loadHistory()
    }
    
    // Format date for display
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 