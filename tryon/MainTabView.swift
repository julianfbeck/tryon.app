import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = TryOnViewModel()
    
    var body: some View {
        TabView {
            TryOnView()
                .tabItem {
                    Label("Try On", systemImage: "tshirt.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(viewModel)
        .accentColor(.accentColor) // This uses the asset catalog's accent color
    }
}

// Helper extension to convert SwiftUI Color to UIColor
extension UIColor {
    convenience init(_ color: Color) {
        let components = color.components()
        self.init(red: components.r, green: components.g, blue: components.b, alpha: components.a)
    }
}

// Helper extension to get components from Color
extension Color {
    func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let scanner = Scanner(string: self.description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        
        // Default fallback color components
        let fallback = (r: CGFloat(0.3), g: CGFloat(0.35), b: CGFloat(0.95), a: CGFloat(1.0))
        
        // Try to get color components, use fallback if it fails
        if scanner.scanHexInt64(&hexNumber) {
            r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000ff) / 255
            
            return (r, g, b, a)
        }
        
        return fallback
    }
}

#Preview {
    MainTabView()
} 