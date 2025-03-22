import Foundation
import SwiftUI
import os.log

// Model for try-on results
struct TryOnResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    
    // Image file names - we'll store actual images separately
    let personImageFileName: String
    let clothImageFileName: String
    let resultImageFileNames: [String]
    
    // Static placeholder image
    static let placeholderImage = UIImage(systemName: "photo.fill") ?? UIImage()
    
    // Computed properties to load images with placeholders
    var personImage: UIImage {
        loadImage(fileName: personImageFileName) ?? Self.placeholderImage
    }
    
    var clothImage: UIImage {
        loadImage(fileName: clothImageFileName) ?? Self.placeholderImage
    }
    
    var resultImages: [UIImage] {
        resultImageFileNames.map { loadImage(fileName: $0) ?? Self.placeholderImage }
    }
    
    // For backward compatibility
    var resultImage: UIImage {
        resultImages.first ?? Self.placeholderImage
    }
    
    private func loadImage(fileName: String) -> UIImage? {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let imagePath = documentsPath.appendingPathComponent("images").appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: imagePath),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    init(id: UUID = UUID(), personImage: UIImage, clothImage: UIImage, resultImages: [UIImage], timestamp: Date) {
        self.id = id
        self.timestamp = timestamp
        
        // Generate unique filenames
        self.personImageFileName = "\(id)-person.jpg"
        self.clothImageFileName = "\(id)-cloth.jpg"
        self.resultImageFileNames = resultImages.enumerated().map { index, _ in
            "\(id)-result-\(index).jpg"
        }
        
        // Save images to disk
        self.saveImage(personImage, fileName: personImageFileName)
        self.saveImage(clothImage, fileName: clothImageFileName)
        
        // Save all result images
        for (index, image) in resultImages.enumerated() {
            self.saveImage(image, fileName: resultImageFileNames[index])
        }
    }
    
    // Convenience initializer for a single result image
    init(id: UUID = UUID(), personImage: UIImage, clothImage: UIImage, resultImage: UIImage, timestamp: Date) {
        self.init(id: id, personImage: personImage, clothImage: clothImage, resultImages: [resultImage], timestamp: timestamp)
    }
    
    private func saveImage(_ image: UIImage, fileName: String) {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let imagesPath = documentsPath.appendingPathComponent("images")
        
        // Create images directory if it doesn't exist
        if !fileManager.fileExists(atPath: imagesPath.path) {
            try? fileManager.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        }
        
        let imagePath = imagesPath.appendingPathComponent(fileName)
        try? image.jpegData(compressionQuality: 0.8)?.write(to: imagePath)
    }
}

// View for displaying a TryOnResult
struct TryOnResultView: View {
    let result: TryOnResult
    @State private var selectedImage: UIImage?
    @State private var isImagePresented = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text(formatDate(result.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                makeImageView(result.personImage, "Person")
                makeImageView(result.clothImage, "Clothing")
                
                // Display first result image in history view
                if let firstResultImage = result.resultImages.first {
                    makeImageView(firstResultImage, "Result")
                }
            }
        }
        .padding()
    }
    
    private func makeImageView(_ image: UIImage, _ label: String) -> some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    selectedImage = image
                    isImagePresented = true
                }
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Actor to handle the try-on service with thread safety
actor TryOnService {
    private var history: [TryOnResult] = []
    private let networkService = NetworkService()
    private let logger = Logger(subsystem: "com.juli.tryon", category: "TryOnService")
    
    init() {
        loadHistoryFromDisk()
    }
    
    func tryOnCloth(personImage: UIImage, clothImage: UIImage, isFreeRetry: Bool = false, imageCount: Int = 4, resultId: UUID? = nil) async throws -> TryOnResult {
        // Call the API
        let resultImages = try await networkService.tryOnCloth(
            personImage: personImage,
            clothImage: clothImage,
            isFreeRetry: isFreeRetry,
            imageCount: imageCount
        )
        
        // Create temporary result for displaying - but don't save to history yet
        let result = TryOnResult(
            id: resultId ?? UUID(),
            personImage: personImage,
            clothImage: clothImage,
            resultImages: resultImages,
            timestamp: Date()
        )
        
        return result
    }
    
    // Save only the selected image to history
    func saveSelectedResult(personImage: UIImage, clothImage: UIImage, selectedImage: UIImage) async -> TryOnResult {
        // Create result with only the selected image
        let result = TryOnResult(
            personImage: personImage,
            clothImage: clothImage,
            resultImage: selectedImage,
            timestamp: Date()
        )
        
        // Add to history, keeping only last 20 items
        history.append(result)
        if history.count > 20 {
            history = Array(history.suffix(20))
        }
        
        // Save updated history to disk
        saveHistoryToDisk()
        
        return result
    }
    
    // Get all history items
    func getHistory() async -> [TryOnResult] {
        return history
    }
    
    // Clear history
    func clearHistory() async {
        // Delete all image files
        deleteAllHistoryImages()
        
        history = []
        saveHistoryToDisk()
    }
    
    private func getHistoryFileURL() -> URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("history.json")
    }
    
    private func loadHistoryFromDisk() {
        guard let fileURL = getHistoryFileURL(),
              let data = try? Data(contentsOf: fileURL),
              let loadedHistory = try? JSONDecoder().decode([TryOnResult].self, from: data) else {
            return
        }
        history = loadedHistory
    }
    
    private func saveHistoryToDisk() {
        guard let fileURL = getHistoryFileURL(),
              let data = try? JSONEncoder().encode(history) else {
            return
        }
        try? data.write(to: fileURL)
    }
    
    private func deleteAllHistoryImages() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let imagesPath = documentsPath.appendingPathComponent("images")
        try? FileManager.default.removeItem(at: imagesPath)
    }
}

// Extension to help with UIImage to/from Data conversion
extension UIImage {
    func toData() -> Data? {
        return self.jpegData(compressionQuality: 0.8)
    }
} 
