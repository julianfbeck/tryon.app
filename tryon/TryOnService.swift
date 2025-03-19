import Foundation
import SwiftUI

// Actor to handle the try-on service with thread safety
actor TryOnService {
    private var history: [TryOnResult] = []
    
    // Mock function to simulate sending images to backend
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> TryOnResult {
        // Simulate network delay
        try await Task.sleep(for: .seconds(2))
        
        // In a real app, this would send the images to a backend service
        // and receive a processed image back. For now, we'll mock it.
        
        // Mock result - in a real app this would be the returned image from backend
        let mockResultImage = await mockMergeImages(personImage: personImage, clothImage: clothImage)
        
        let result = TryOnResult(
            id: UUID(),
            personImage: personImage,
            clothImage: clothImage,
            resultImage: mockResultImage,
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
    
    // Mock function to merge images (this would be done by the backend in reality)
    private func mockMergeImages(personImage: UIImage, clothImage: UIImage) async -> UIImage {
        // This is a very simplified mock that just composites the images
        // In reality, this would be a complex AI process on the backend
        
        let size = CGSize(width: personImage.size.width, height: personImage.size.height)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let resultImage = renderer.image { ctx in
            // Draw person image first
            personImage.draw(in: CGRect(origin: .zero, size: size))
            
            // Draw cloth image on top with some transparency
            // In a real app, the backend would handle proper alignment and fitting
            let clothRect = CGRect(
                x: size.width * 0.2,
                y: size.height * 0.3,
                width: size.width * 0.6,
                height: size.height * 0.4
            )
            clothImage.draw(in: clothRect, blendMode: .normal, alpha: 0.85)
        }
        
        return resultImage
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