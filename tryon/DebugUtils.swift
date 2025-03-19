import Foundation
import os.log
import UIKit

// Debug utility to help diagnose stack and memory issues
class DebugUtils {
    private static let logger = Logger(subsystem: "com.juli.tryon", category: "DebugUtils")
    private static var isLoggingEnabled = true
    
    // Enable/disable debug logging
    static func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        logger.log("Debug logging \(enabled ? "enabled" : "disabled")")
    }
    
    // Log memory usage with a custom tag
    static func logMemoryUsage(tag: String) {
        guard isLoggingEnabled else { return }
        
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            logger.log("MEMORY [\(tag)]: \(usedMB, format: .fixed(precision: 2)) MB used")
        } else {
            logger.error("Error getting memory usage")
        }
    }
    
    // Log image details
    static func logImageDetails(image: UIImage?, label: String) {
        guard isLoggingEnabled else { return }
        
        if let image = image {
            logger.log("Image [\(label)]: \(image.size.width)x\(image.size.height) pixels, scale: \(image.scale)")
            
            if let jpegData = image.jpegData(compressionQuality: 1.0) {
                logger.log("Image [\(label)] data size: \(jpegData.count / 1024) KB")
            } else {
                logger.log("Image [\(label)] could not get data size")
            }
        } else {
            logger.log("Image [\(label)]: nil")
        }
    }
    
    // Log current call stack
    static func logCallStack(tag: String) {
        guard isLoggingEnabled else { return }
        
        let symbols = Thread.callStackSymbols
        logger.log("CALL STACK [\(tag)]: \(symbols.count) frames deep")
        
        for (index, symbol) in symbols.prefix(20).enumerated() {
            logger.log("Frame \(index): \(symbol)")
        }
        
        if symbols.count > 20 {
            logger.log("... \(symbols.count - 20) more frames ...")
        }
    }
    
    // Clear temporary files
    static func clearTemporaryFiles() {
        guard isLoggingEnabled else { return }
        
        let fileManager = FileManager.default
        let tempDirectory = NSTemporaryDirectory()
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: tempDirectory)
            var totalSize: UInt64 = 0
            var count = 0
            
            for file in files {
                let filePath = tempDirectory + file
                
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: filePath)
                    if let fileSize = attributes[.size] as? UInt64 {
                        totalSize += fileSize
                    }
                    
                    try fileManager.removeItem(atPath: filePath)
                    count += 1
                } catch {
                    logger.error("Failed to delete temp file: \(error.localizedDescription)")
                }
            }
            
            logger.log("Cleared \(count) temporary files, freed \(totalSize / 1024) KB")
        } catch {
            logger.error("Failed to clear temporary files: \(error.localizedDescription)")
        }
    }
    
    // Check for potential issues in the app
    static func checkForIssues() -> [String] {
        guard isLoggingEnabled else { return [] }
        
        var issues: [String] = []
        
        // Check memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            if usedMB > 150 {
                issues.append("High memory usage: \(Int(usedMB)) MB")
            }
        }
        
        return issues
    }
} 