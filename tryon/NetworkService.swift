import Foundation
import UIKit
import os.log

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(Error)
    case serverError(Int, String)
    case decodingError
    case noData
    case timeoutError
    case memoryError
    case compressionError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError:
            return "Failed to process server response"
        case .noData:
            return "No data returned from server"
        case .timeoutError:
            return "Request timed out. The server is taking too long to respond."
        case .memoryError:
            return "Memory error: Not enough memory to process the images"
        case .compressionError:
            return "Could not compress the image to an acceptable size"
        }
    }
}

actor NetworkService {
    // Logger instance
    private let logger = Logger(subsystem: "com.juli.tryon", category: "NetworkService")
    
    // Production API URL
    private let apiURL = "https://tryon.app.juli.sh/api/tryon"
    
    // Constants for image processing
    private let maxImageDimension: CGFloat = 1024
    private let targetImageSize: Int = 1 * 1024 * 1024  // 1MB target size
    private let maxImageSize: Int = 2 * 1024 * 1024     // 2MB absolute maximum
    private let minCompressionQuality: CGFloat = 0.1    // Minimum acceptable quality
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> UIImage {
        do {
            logger.log("Starting tryOnCloth request with image sizes - Person: \(personImage.size.width)x\(personImage.size.height), Clothing: \(clothImage.size.width)x\(clothImage.size.height)")
            
            guard let url = URL(string: apiURL) else {
                logger.error("Invalid URL: \(self.apiURL)")
                throw NetworkError.invalidURL
            }
            
            // Report memory usage
            reportMemoryUsage("Before image processing")
            
            // Process person image
            logger.log("Processing person image")
            let (processedPersonImage, personImageData) = try await processImage(
                personImage,
                type: "person",
                maxDimension: maxImageDimension,
                targetSize: targetImageSize,
                maxSize: maxImageSize
            )
            
            // Process clothing image
            logger.log("Processing clothing image")
            let (processedClothImage, clothImageData) = try await processImage(
                clothImage,
                type: "clothing",
                maxDimension: maxImageDimension,
                targetSize: targetImageSize,
                maxSize: maxImageSize
            )
            
            // Report memory usage after processing
            reportMemoryUsage("After image processing")
            
            // Create request with timeout
            logger.log("Creating HTTP request")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 90
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // Create form data
            logger.log("Creating multipart form data")
            var httpBody: Data?
            try autoreleasepool {
                httpBody = createFormData(boundary: boundary, personData: personImageData, clothData: clothImageData)
            }
            
            guard let requestBody = httpBody else {
                logger.error("Failed to create form data")
                throw NetworkError.noData
            }
            
            logger.log("Form data size: \(requestBody.count) bytes")
            request.httpBody = requestBody
            
            // Report memory usage
            reportMemoryUsage("Before network request")
            
            // Configure session
            logger.log("Configuring URLSession")
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 90
            config.timeoutIntervalForResource = 300
            let session = URLSession(configuration: config)
            
            // Send request
            logger.log("Sending network request to \(url.absoluteString)")
            let (data, response) = try await session.data(for: request)
            logger.log("Received response with \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NetworkError.invalidResponse
            }
            
            logger.log("HTTP status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                logger.log("Processing successful response")
                
                // Report memory usage
                reportMemoryUsage("Before creating result image")
                
                var resultImage: UIImage?
                try autoreleasepool {
                    resultImage = UIImage(data: data)
                }
                
                guard let image = resultImage else {
                    logger.error("Failed to create image from response data")
                    throw NetworkError.decodingError
                }
                
                logger.log("Successfully created result image: \(image.size.width)x\(image.size.height)")
                
                // Report memory usage
                reportMemoryUsage("After creating result image")
                
                return image
            } else {
                logger.error("Server returned error status: \(httpResponse.statusCode)")
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["error"] ?? "Unknown error"
                logger.error("Error message: \(errorMessage ?? "None")")
                throw NetworkError.serverError(httpResponse.statusCode, errorMessage ?? "Unknown error")
            }
        } catch let error as NetworkError {
            logger.error("NetworkError: \(error.localizedDescription)")
            throw error
        } catch let error as URLError where error.code == .timedOut {
            logger.error("URL timeout error: \(error.localizedDescription)")
            throw NetworkError.timeoutError
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            if error.localizedDescription.contains("memory") {
                throw NetworkError.memoryError
            }
            throw NetworkError.requestFailed(error)
        }
    }
    
    private func processImage(_ image: UIImage, type: String, maxDimension: CGFloat, targetSize: Int, maxSize: Int) async throws -> (UIImage, Data) {
        logger.log("Processing \(type) image: \(image.size.width)x\(image.size.height)")
        
        // First resize if needed
        let resizedImage = resizeImageIfNeeded(image, maxDimension: maxDimension)
        logger.log("\(type) image resized to: \(resizedImage.size.width)x\(resizedImage.size.height)")
        
        // Try to compress to target size
        let imageData = try await compressImage(resizedImage, type: type, targetSize: targetSize, maxSize: maxSize)
        logger.log("\(type) image compressed to \(imageData.count) bytes")
        
        return (resizedImage, imageData)
    }
    
    private func compressImage(_ image: UIImage, type: String, targetSize: Int, maxSize: Int) async throws -> Data {
        var compressionQuality: CGFloat = 0.8
        var imageData: Data
        
        // Try progressively lower quality until we get under target size
        repeat {
            guard let data = image.jpegData(compressionQuality: compressionQuality) else {
                logger.error("Failed to compress \(type) image at quality \(compressionQuality)")
                throw NetworkError.compressionError
            }
            
            imageData = data
            
            if imageData.count <= targetSize {
                logger.log("\(type) image compressed successfully at quality \(compressionQuality)")
                break
            }
            
            compressionQuality -= 0.1
            logger.log("Retrying \(type) image compression at quality \(compressionQuality)")
            
            // Check if we've hit minimum quality
            if compressionQuality < minCompressionQuality {
                if imageData.count <= maxSize {
                    logger.warning("\(type) image couldn't reach target size, but is under max size")
                    break
                } else {
                    logger.error("\(type) image too large even at minimum quality")
                    throw NetworkError.compressionError
                }
            }
            
            // Allow other tasks to proceed
            await Task.yield()
            
        } while true
        
        return imageData
    }
    
    private func createFormData(boundary: String, personData: Data, clothData: Data) -> Data {
        logger.log("Starting form data creation")
        var body = Data()
        
        // Add person image data
        logger.log("Adding person image to form data")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"person\"; filename=\"person.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(personData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add clothing image data
        logger.log("Adding clothing image to form data")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"clothing\"; filename=\"clothing.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(clothData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End of form data
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        logger.log("Completed form data creation, size: \(body.count) bytes")
        return body
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        logger.log("Original image size: \(originalSize.width)x\(originalSize.height)")
        
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            logger.log("Image already within size limits, no resize needed")
            return image
        }
        
        var newSize: CGSize
        if originalSize.width > originalSize.height {
            let ratio = maxDimension / originalSize.width
            newSize = CGSize(width: maxDimension, height: originalSize.height * ratio)
        } else {
            let ratio = maxDimension / originalSize.height
            newSize = CGSize(width: originalSize.width * ratio, height: maxDimension)
        }
        
        logger.log("Resizing to: \(newSize.width)x\(newSize.height)")
        
        var resizedImage: UIImage?
        autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            defer { UIGraphicsEndImageContext() }
            
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        
        guard let result = resizedImage else {
            logger.error("Image resize failed")
            return image
        }
        
        logger.log("Image resized successfully")
        return result
    }
    
    private func reportMemoryUsage(_ context: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            logger.log("MEMORY [\(context)]: \(usedMB, format: .fixed(precision: 2)) MB used")
        } else {
            logger.error("Error getting memory usage")
        }
    }
} 