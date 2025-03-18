import Foundation
import UIKit

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(Error)
    case serverError(Int, String)
    case decodingError
    case noData
    
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
        }
    }
}

actor NetworkService {
    // Production API URL
    private let apiURL = "https://tryon.app.juli.sh/api/tryon"
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage) async throws -> UIImage {
        guard let url = URL(string: apiURL) else {
            throw NetworkError.invalidURL
        }
        
        guard let personData = personImage.jpegData(compressionQuality: 0.8),
              let clothData = clothImage.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.noData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createFormData(boundary: boundary, personData: personData, clothData: clothData)
        request.httpBody = httpBody
        
        do {
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
                // Try to parse error message from response
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["error"] ?? "Unknown error"
                throw NetworkError.serverError(httpResponse.statusCode, errorMessage ?? "Unknown error")
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.requestFailed(error)
        }
    }
    
    private func createFormData(boundary: String, personData: Data, clothData: Data) -> Data {
        var body = Data()
        
        // Add person image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"person\"; filename=\"person.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(personData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add clothing image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"clothing\"; filename=\"clothing.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(clothData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End of form data
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
} 