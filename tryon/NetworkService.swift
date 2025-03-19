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
    case imageTooLarge
    
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
        case .imageTooLarge:
            return "One or both images are too large. Please use smaller images."
        }
    }
}

actor NetworkService {
    // Logger instance
    private let logger = Logger(subsystem: "com.juli.tryon", category: "NetworkService")
    
    // Production API URL
    private let apiURL = "https://tryon.app.juli.sh/api/tryon"
    
    // Maximum sizes for network transmission
    private let maxImageDimension: CGFloat = 1024 // Maximum dimension for any image
    private let maxFileSize: Int = 4 * 1024 * 1024 // 4MB max total for both images
    private let maxCompressionAttempts = 5 // Maximum number of compression attempts
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> UIImage {
        do {
            logger.log("Starting tryOnCloth request with image sizes - Person: \(personImage.size.width)x\(personImage.size.height), Clothing: \(clothImage.size.width)x\(clothImage.size.height)")
            
            guard let url = URL(string: apiURL) else {
                logger.error("Invalid URL: \(self.apiURL)")
                throw NetworkError.invalidURL
            }
            
            // Report memory usage
            reportMemoryUsage("Before image processing")
            
            // Resize images to prevent excessive memory usage
            logger.log("Resizing images if needed")
            
            // Resize and compress images
            let (resizedPersonImage, resizedClothImage) = try await prepareImagesForUpload(personImage, clothImage)
            
            // Report memory usage
            reportMemoryUsage("After image preparation")
            
            // Create request with timeout
            logger.log("Creating HTTP request")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 90
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // Create form data with explicit memory management
            logger.log("Creating multipart form data")
            var httpBody: Data?
            try autoreleasepool {
                httpBody = createFormData(boundary: boundary, personData: resizedPersonImage, clothData: resizedClothImage)
            }
            
            guard let requestBody = httpBody else {
                logger.error("Failed to create form data")
                throw NetworkError.noData
            }
            
            logger.log("Form data size: \(requestBody.count) bytes")
            request.httpBody = requestBody
            
            // Report memory usage
            reportMemoryUsage("Before network request")
            
            logger.log("Configuring URLSession")
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 90
            config.timeoutIntervalForResource = 300 // 5 minute timeout for resource
            let session = URLSession(configuration: config)
            
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
                
                // Try to parse error message from response
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
            
            // Check if error might be related to memory
            if error.localizedDescription.contains("memory") {
                throw NetworkError.memoryError
            }
            
            throw NetworkError.requestFailed(error)
        }
    }
    
    // New method to prepare and compress images for upload
    private func prepareImagesForUpload(_ personImage: UIImage, _ clothImage: UIImage) async throws -> (Data, Data) {
        // First, resize images if they're too large
        let resizedPersonImage = resizeImageIfNeeded(personImage, maxDimension: maxImageDimension)
        let resizedClothImage = resizeImageIfNeeded(clothImage, maxDimension: maxImageDimension)
        
        logger.log("Images resized - Person: \(resizedPersonImage.size.width)x\(resizedPersonImage.size.height), Cloth: \(resizedClothImage.size.width)x\(resizedClothImage.size.height)")
        
        // Compress with increasing compression until total size is acceptable
        var compressionQuality: CGFloat = 0.7
        var personData: Data?
        var clothData: Data?
        var attempts = 0
        
        // Keep attempting compression until we're below the max size or reach max attempts
        while attempts < maxCompressionAttempts {
            try autoreleasepool {
                personData = resizedPersonImage.jpegData(compressionQuality: compressionQuality)
                clothData = resizedClothImage.jpegData(compressionQuality: compressionQuality)
            }
            
            guard let personImageData = personData, let clothImageData = clothData else {
                logger.error("Failed to convert images to data")
                throw NetworkError.noData
            }
            
            let totalSize = personImageData.count + clothImageData.count
            logger.log("Compression attempt \(attempts+1): quality=\(compressionQuality), person=\(personImageData.count/1024)KB, cloth=\(clothImageData.count/1024)KB, total=\(totalSize/1024)KB")
            
            if totalSize <= maxFileSize {
                logger.log("Acceptable compression achieved")
                return (personImageData, clothImageData)
            }
            
            // Reduce quality for next attempt
            compressionQuality -= 0.15
            if compressionQuality < 0.3 {
                compressionQuality = 0.3 // Don't go below 0.3 quality
            }
            
            attempts += 1
        }
        
        // If we get here and have data but it's still too large, use the last compression result
        if let personImageData = personData, let clothImageData = clothData {
            let totalSize = personImageData.count + clothImageData.count
            logger.warning("Images still large after compression: \(totalSize/1024)KB, proceeding anyway")
            return (personImageData, clothImageData)
        }
        
        // If we couldn't get any data at all
        logger.error("Failed to compress images to an acceptable size")
        throw NetworkError.imageTooLarge
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
    
    // Helper function to resize images if they're too large
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        
        // Log original image details
        logger.log("Original image size: \(originalSize.width)x\(originalSize.height)")
        
        // If image is already smaller than max dimension, return it as is
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            logger.log("Image already within size limits, no resize needed")
            return image
        }
        
        // Calculate new size while maintaining aspect ratio
        var newSize: CGSize
        if originalSize.width > originalSize.height {
            let ratio = maxDimension / originalSize.width
            newSize = CGSize(width: maxDimension, height: originalSize.height * ratio)
        } else {
            let ratio = maxDimension / originalSize.height
            newSize = CGSize(width: originalSize.width * ratio, height: maxDimension)
        }
        
        logger.log("Resizing to: \(newSize.width)x\(newSize.height)")
        
        // Perform resize with more explicit memory management
        var resizedImage: UIImage?
        
        autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            
            UIGraphicsEndImageContext()
        }
        
        // If resize failed, log and return original
        guard let result = resizedImage else {
            logger.error("Image resize failed")
            return image
        }
        
        logger.log("Image resized successfully")
        return result
    }
    
    // Helper function to report memory usage
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