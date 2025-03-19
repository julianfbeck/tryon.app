import Foundation
import SwiftUI
import os.log

// Actor to handle the try-on service with thread safety
actor TryOnService {
    private var history: [TryOnResult] = []
    private let networkService = NetworkService()
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnService")
    
    // Constants for image processing
    private let maxDimension: CGFloat = 1024
    private let targetFileSize: Int = 1 * 1024 * 1024  // 1MB target
    private let maxFileSize: Int = 2 * 1024 * 1024     // 2MB max
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> TryOnResult {
        logger.log("Processing images before sending to API")
        
        // Process person image
        let processedPersonImage = try await processImage(personImage, type: "person")
        logger.log("Person image processed: \(processedPersonImage.size.width)x\(processedPersonImage.size.height)")
        
        // Process clothing image
        let processedClothImage = try await processImage(clothImage, type: "clothing")
        logger.log("Clothing image processed: \(processedClothImage.size.width)x\(processedClothImage.size.height)")
        
        // Call the real API with processed images
        let resultImage = try await networkService.tryOnCloth(
            personImage: processedPersonImage,
            clothImage: processedClothImage
        )
        
        // Create result with real API response
        let result = TryOnResult(
            id: UUID(),
            personImage: personImage,        // Keep original for history
            clothImage: clothImage,          // Keep original for history
            resultImage: resultImage,
            timestamp: Date()
        )
        
        // Add to history
        history.append(result)
        
        // Keep only the last 20 items to prevent memory growth
        if history.count > 20 {
            history = Array(history.suffix(20))
        }
        
        return result
    }
    
    private func processImage(_ image: UIImage, type: String) async throws -> UIImage {
        logger.log("Processing \(type) image of size: \(image.size.width)x\(image.size.height)")
        
        // First check if we need to resize
        let resizedImage = resizeImageIfNeeded(image)
        
        // Then check if we need to compress
        if let imageData = resizedImage.jpegData(compressionQuality: 1.0),
           imageData.count > targetFileSize {
            logger.log("\(type) image needs compression, current size: \(imageData.count/1024)KB")
            
            // Try progressive compression
            var quality: CGFloat = 0.8
            while quality >= 0.1 {
                if let compressedData = resizedImage.jpegData(compressionQuality: quality),
                   let compressedImage = UIImage(data: compressedData) {
                    if compressedData.count <= targetFileSize {
                        logger.log("\(type) image compressed successfully at quality \(quality), final size: \(compressedData.count/1024)KB")
                        return compressedImage
                    } else if compressedData.count <= maxFileSize && quality <= 0.2 {
                        // Accept slightly larger size if we're already at low quality
                        logger.log("\(type) image compressed to acceptable size at quality \(quality), final size: \(compressedData.count/1024)KB")
                        return compressedImage
                    }
                }
                quality -= 0.1
                await Task.yield() // Allow other tasks to proceed
            }
            
            logger.error("Could not compress \(type) image to acceptable size")
            throw NetworkError.compressionError
        }
        
        return resizedImage
    }
    
    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size
        
        if size.width <= maxDimension && size.height <= maxDimension {
            logger.log("Image already within size limits: \(size.width)x\(size.height)")
            return image
        }
        
        var newSize: CGSize
        if size.width > size.height {
            let ratio = maxDimension / size.width
            newSize = CGSize(width: maxDimension, height: size.height * ratio)
        } else {
            let ratio = maxDimension / size.height
            newSize = CGSize(width: size.width * ratio, height: maxDimension)
        }
        
        logger.log("Resizing image from \(size.width)x\(size.height) to \(newSize.width)x\(newSize.height)")
        
        var resizedImage: UIImage?
        autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            defer { UIGraphicsEndImageContext() }
            
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        
        return resizedImage ?? image
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