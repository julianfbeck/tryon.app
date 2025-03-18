import Foundation
import SwiftUI

// Actor to handle the try-on service with thread safety
actor TryOnService {
    private var history: [TryOnResult] = []
    private let networkService = NetworkService()
    
    // Function to try on clothing using the API
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> TryOnResult {
        // Use the network service to process the images
        let resultImage = try await networkService.tryOnCloth(personImage: personImage, clothImage: clothImage)
        
        let result = TryOnResult(
            id: UUID(),
            personImage: personImage,
            clothImage: clothImage,
            resultImage: resultImage,
            timestamp: Date()
        )
        
        // Add to history
        history.append(result)
        
        return result
    }
    
    // Get all history items
    func getHistory() async -> [TryOnResult] {
        return history
    }
    
    // Clear history
    func clearHistory() async {
        history = []
    }
}

// Model for try-on results
struct TryOnResult: Identifiable {
    let id: UUID
    let personImage: UIImage
    let clothImage: UIImage
    let resultImage: UIImage
    let timestamp: Date
}

// Extension to help with UIImage to/from Data conversion
extension UIImage {
    func toData() -> Data? {
        return self.jpegData(compressionQuality: 0.8)
    }
} 