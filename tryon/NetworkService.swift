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

actor NetworkService {
    private let logger = Logger(subsystem: "com.juli.tryon", category: "NetworkService")
    private let apiURL = "http://localhost:8787/api/tryon"
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> UIImage {
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
        
        // Create request body
        let requestBody: [String: Any] = [
            "person": [
                "data": personBase64,
                "mime_type": "image/jpeg"
            ],
            "clothing": [
                "data": clothBase64,
                "mime_type": "image/jpeg"
            ]
        ]
        
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
            guard let resultImage = UIImage(data: data) else {
                throw NetworkError.decodingError
            }
            return resultImage
        } else {
            let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["error"] ?? "Unknown error"
            throw NetworkError.serverError(httpResponse.statusCode, errorMessage ?? "Unknown error")
        }
    }
} 
