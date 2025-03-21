//
//  tryonApp.swift
//  tryon
//
//  Created by Julian Beck on 17.03.25.
//

import SwiftUI
import RevenueCat
@main
struct tryonApp: App {
    @StateObject var globalViewModel = GlobalViewModel()
    
    init() {
           Purchases.configure(withAPIKey: "appl_KIgdiugXJfhqQJjnhXZnVapWakD")
       }
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(globalViewModel)
                .onAppear {
                    Plausible.shared.configure(domain: "tryon.juli.sh", endpoint: "https://stats.juli.sh/api/event")
                }
        }
    }
}
