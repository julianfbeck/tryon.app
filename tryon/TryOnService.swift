import Foundation
import SwiftUI
import os.log

// Actor to handle the try-on service with thread safety
actor TryOnService {
    private var history: [TryOnResult] = []
    private let networkService = NetworkService()
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnService")
    
    // Function to try on clothing using the API
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> TryOnResult {
        logger.log("Starting tryOnCloth with person image: \(personImage.size.width)x\(personImage.size.height), cloth image: \(clothImage.size.width)x\(clothImage.size.height)")
        
        do {
            // Use the network service to process the images
            let resultImage = try await networkService.tryOnCloth(personImage: personImage, clothImage: clothImage)
            
            logger.log("Successfully received result image: \(resultImage.size.width)x\(resultImage.size.height)")
            
            let result = TryOnResult(
                id: UUID(),
                personImage: personImage,
                clothImage: clothImage,
                resultImage: resultImage,
                timestamp: Date()
            )
            
            // Add to history (limit to 20 most recent items to prevent memory growth)
            history.append(result)
            if history.count > 20 {
                logger.log("Trimming history to last 20 items")
                history = Array(history.suffix(20))
            }
            
            logger.log("Try-on completed and result added to history (total: \(history.count) items)")
            return result
        } catch {
            logger.error("Error in tryOnCloth: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get all history items
    func getHistory() async -> [TryOnResult] {
        logger.log("Getting history (\(history.count) items)")
        return history
    }
    
    // Clear history
    func clearHistory() async {
        logger.log("Clearing history")
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