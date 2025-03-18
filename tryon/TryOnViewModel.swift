import Foundation
import SwiftUI

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
            errorMessage = "Please select both a person image and a cloth image"
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
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
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