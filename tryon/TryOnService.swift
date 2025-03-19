import Foundation
import SwiftUI
import os.log

// Actor to handle the try-on service with thread safety
actor TryOnService {
    private var history: [TryOnResult] = []
    private let networkService = NetworkService()
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnService")
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> TryOnResult {
        // Call the API
        let resultImage = try await networkService.tryOnCloth(
            personImage: personImage,
            clothImage: clothImage
        )
        
        // Create result
        let result = TryOnResult(
            id: UUID(),
            personImage: personImage,
            clothImage: clothImage,
            resultImage: resultImage,
            timestamp: Date()
        )
        
        // Add to history, keeping only last 20 items
        history.append(result)
        if history.count > 20 {
            history = Array(history.suffix(20))
        }
        
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