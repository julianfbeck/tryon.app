//
//  PlausibleError.swift
//  tryon
//
//  Created by Julian Beck on 21.03.25.
//


//
//  Plausible.swift
//  icongenerator
//
//  Created by Julian Beck on 15.09.24.
//

import Foundation
import UIKit

public enum PlausibleError: Error {
    case domainNotSet
    case invalidDomain
    case eventIsPageview
}

/// PlausibleSwift is an implementation of the Plausible Analytics REST events API
public class Plausible {
    public private(set) var endpoint = ""
    public private(set) var domain = ""
    
    // Shared instance
    public static let shared = Plausible()
    
    private let queue = DispatchQueue(label: "com.plausibleswift.queue", qos: .utility)
    private let userDefaults = UserDefaults.standard
    private let appOpenCountKey = "com.plausibleswift.appOpenCount"
    
    private init() {}
    
    /// Initialize the shared instance with endpoint and domain
    /// - Parameters:
    ///   - domain: The domain for your Plausible analytics
    ///   - endpoint: The endpoint URL for Plausible API
    public func configure(domain: String, endpoint: String) {
        self.endpoint = endpoint
        self.domain = domain
        
        // Increment and get the updated app open count
        let appOpenCount = incrementAppOpenCount()
        
        // Gather device info and add app open count
        var deviceInfo = gatherDeviceInfo()
        deviceInfo["app_open_count"] = String(appOpenCount)
        
        // Auto-track open event with device info and app open count
        trackEvent(event: "open", path: "/open", properties: deviceInfo)
        
        if appOpenCount == 1 {
            trackEvent(event: "install", path: "/install")
        }
    }
    
    /// Sends a pageview event to Plausible for the specified path
    /// - Parameters:
    ///     - path: a URL path to use as the pageview location
    ///     - properties: (optional) a dictionary of key-value pairs that will be attached to this event
    public func trackPageview(path: String, properties: [String: String] = [:]) {
        queue.async { [weak self] in
            guard let self = self, self.domain != "" else { return }
            
            Task {
                do {
                    try await self.plausibleRequest(name: "pageview", path: path, properties: properties)
                } catch {
                    print("Plausible error: \(error)")
                }
            }
        }
    }
    
    /// Sends a named event to Plausible for the specified path
    /// - Parameters:
    ///     - event: an arbitrary event name for your analytics
    ///     - path: a URL path to use as the pageview location
    ///     - properties: (optional) a dictionary of key-value pairs that will be attached to this event
    public func trackEvent(event: String, path: String, properties: [String: String] = [:]) {
        queue.async { [weak self] in
            guard let self = self, event != "pageview" else { return }
            
            Task {
                do {
                    try await self.plausibleRequest(name: event, path: path, properties: properties)
                } catch {
                    print("Plausible error: \(error)")
                }
            }
        }
    }
    
    private func plausibleRequest(name: String, path: String, properties: [String: String]) async throws {
        guard let plausibleEventURL = URL(string: self.endpoint) else {
            throw PlausibleError.invalidDomain
        }

        var req = URLRequest(url: plausibleEventURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var jsonObject: [String: Any] = ["name": name, "url": constructPageviewURL(path: path), "domain": domain]
        if !properties.isEmpty {
            jsonObject["props"] = properties
        }
        
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject)
        req.httpBody = jsonData

        do {
            let (_, _) = try await URLSession.shared.data(for: req)
        } catch {
            print("Plausible network error: \(error)")
        }
    }
    
    private func constructPageviewURL(path: String) -> String {
        let url = URL(string: "https://\(domain)")!
        return url.appendingPathComponent(path).absoluteString
    }
    
    private func gatherDeviceInfo() -> [String: String] {
        let device = UIDevice.current
        let screenSize = UIScreen.main.bounds.size
        let locale = Locale.current
        
        var info: [String: String] = [
            "os_version": device.systemVersion,
            "device_model": device.model,
            "device_name": device.name,
            "screen_width": String(format: "%.0f", screenSize.width),
            "screen_height": String(format: "%.0f", screenSize.height),
            "locale": locale.identifier,
            "language": locale.languageCode ?? "unknown"
        ]
        
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info["app_version"] = appVersion
        }
        
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info["build_number"] = buildNumber
        }
        
        return info
    }
    
    private func incrementAppOpenCount() -> Int {
        let currentCount = userDefaults.integer(forKey: appOpenCountKey)
        let newCount = currentCount + 1
        userDefaults.set(newCount, forKey: appOpenCountKey)
        return newCount
    }
}