import SwiftUI
import PhotosUI
import os.log

// SwiftUI wrapper for PHPickerViewController
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    private let logger = Logger(subsystem: "com.juli.tryon", category: "ImagePicker")
    var onError: ((String) -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        logger.log("Creating PHPickerViewController")
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .compatible
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinator to handle the picker delegate methods
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
            super.init()
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker
            parent.presentationMode.wrappedValue.dismiss()
            
            // Get the selected image
            guard let provider = results.first?.itemProvider else { 
                parent.logger.log("No image selected")
                return
            }
            
            parent.logger.log("Image selected, preparing to load")
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                parent.logger.log("Loading image")
                
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let error = error {
                            self.parent.logger.error("Error loading image: \(error.localizedDescription)")
                            self.parent.onError?("Failed to load image: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let image = image as? UIImage else {
                            self.parent.logger.error("Invalid image format")
                            self.parent.onError?("Invalid image format")
                            return
                        }
                        
                        // Check for reasonable image dimensions
                        if image.size.width <= 0 || image.size.height <= 0 {
                            self.parent.logger.error("Invalid image dimensions: \(image.size.width)x\(image.size.height)")
                            self.parent.onError?("The selected image has invalid dimensions")
                            return
                        }
                        
                        // Check for extremely large images
                        let maxDimension: CGFloat = 4096
                        if image.size.width > maxDimension || image.size.height > maxDimension {
                            self.parent.logger.warning("Very large image selected: \(image.size.width)x\(image.size.height)")
                            
                            // Resize large images automatically
                            if let resizedImage = self.resizeImage(image, to: maxDimension) {
                                self.parent.logger.log("Image resized to: \(resizedImage.size.width)x\(resizedImage.size.height)")
                                self.parent.image = resizedImage
                            } else {
                                self.parent.logger.error("Failed to resize large image")
                                self.parent.onError?("The selected image is too large and couldn't be resized")
                            }
                        } else {
                            self.parent.logger.log("Image loaded successfully: \(image.size.width)x\(image.size.height)")
                            self.parent.image = image
                        }
                    }
                }
            } else {
                parent.logger.error("Selected item is not a compatible image")
                parent.onError?("The selected item is not a compatible image")
            }
        }
        
        // Safely resize very large images
        private func resizeImage(_ image: UIImage, to maxDimension: CGFloat) -> UIImage? {
            let originalSize = image.size
            
            // Calculate new size while maintaining aspect ratio
            var newSize: CGSize
            if originalSize.width > originalSize.height {
                let ratio = maxDimension / originalSize.width
                newSize = CGSize(width: maxDimension, height: originalSize.height * ratio)
            } else {
                let ratio = maxDimension / originalSize.height
                newSize = CGSize(width: originalSize.width * ratio, height: maxDimension)
            }
            
            // Use autoreleasepool for better memory management
            var resizedImage: UIImage?
            
            autoreleasepool {
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                defer { UIGraphicsEndImageContext() }
                
                image.draw(in: CGRect(origin: .zero, size: newSize))
                resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            }
            
            return resizedImage
        }
    }
} 