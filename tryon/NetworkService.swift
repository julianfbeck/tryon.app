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
    case encodingError
    
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
        case .encodingError:
            return "Failed to encode the images"
        }
    }
}

// Response structure for multiple images
struct MultiImageResponse: Decodable {
    let images: [String]
}

actor NetworkService {
    private let logger = Logger(subsystem: "com.juli.tryon", category: "NetworkService")
    private let apiURL = "https://tryon.app.juli.sh/api/tryon"
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage, isFreeRetry: Bool = false, imageCount: Int = 4) async throws -> [UIImage] {
        guard let url = URL(string: apiURL) else {
            logger.error("Invalid URL: \(self.apiURL)")
            throw NetworkError.invalidURL
        }
        
        // Convert images to base64 with moderate compression
        guard let personBase64 = personImage.jpegData(compressionQuality: 0.5)?.base64EncodedString(),
              let clothBase64 = clothImage.jpegData(compressionQuality: 0.5)?.base64EncodedString() else {
            logger.error("Failed to encode images to base64")
            throw NetworkError.encodingError
        }
        
        // Create request body without safety settings
        var requestBody: [String: Any] = [
            "person": [
                "data": personBase64,
                "mime_type": "image/jpeg"
            ],
            "clothing": [
                "data": clothBase64,
                "mime_type": "image/jpeg"
            ],
            "imageCount": imageCount
        ]
        
        // Add free retry flag to inform the server (if needed)
        if isFreeRetry {
            requestBody["isFreeRetry"] = true
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        
        // Serialize request body
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            // Check the content type to determine how to handle the response
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            
            if contentType.contains("image/") {
                // Direct image response (for single image case)
                guard let resultImage = UIImage(data: data) else {
                    throw NetworkError.decodingError
                }
                return [resultImage]
            } else if contentType.contains("application/json") {
                // JSON response with multiple images
                do {
                    let response = try JSONDecoder().decode(MultiImageResponse.self, from: data)
                    
                    // Convert base64 strings to images
                    let images = try response.images.map { base64String -> UIImage in
                        guard let imageData = Data(base64Encoded: base64String),
                              let image = UIImage(data: imageData) else {
                            throw NetworkError.decodingError
                        }
                        return image
                    }
                    
                    guard !images.isEmpty else {
                        throw NetworkError.noData
                    }
                    
                    return images
                } catch {
                    logger.error("Failed to decode JSON response: \(error.localizedDescription)")
                    throw NetworkError.decodingError
                }
            } else {
                logger.error("Unexpected content type: \(contentType)")
                throw NetworkError.invalidResponse
            }
        } else {
            let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["error"] ?? "Unknown error"
            throw NetworkError.serverError(httpResponse.statusCode, errorMessage ?? "Unknown error")
        }
    }
} 
