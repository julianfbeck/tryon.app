import SwiftUI
import RevenueCat

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var globalViewModel: GlobalViewModel
    
    // URLs for legal documents
    private let privacyURL = URL(string: "https://julianbeck.notion.site/Privacy-Policy-for-TryOn-16f96d29972e803db34ef8b4a558c1a4")!
    private let termsURL = URL(string: "https://julianbeck.notion.site/TryOn-16f96d29972e8004a92afaca97d753b0")!
    private let supportURL = URL(string: "https://julianbeck.notion.site/TryOn-Support-13296d29972e807ba819e0385fbed4df")!
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(0.8),
                        Color.accentColor.opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                HStack {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Settings")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                if globalViewModel.isPro {
                                    HStack {
                                        Image(systemName: "crown.fill")
                                            .foregroundColor(.yellow)
                                        Text("Pro Member")
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        List {
                            Section {
                                if !globalViewModel.isPro {
                                    SettingsRow(
                                        icon: "star.fill",
                                        iconColor: .red,
                                        title: "Upgrade to Pro",
                                        subtitle: "Unlimited try-ons"
                                    ) {
                                        globalViewModel.isShowingPayWall.toggle()
                                    }
                                }
                                
                                SettingsRow(
                                    icon: "star.fill",
                                    iconColor: .yellow,
                                    title: "Rate TryOn",
                                    subtitle: "Leave a review on the App Store"
                                ) {
                                    if let writeReviewURL = URL(string: "https://apps.apple.com/app/id6476532071?action=write-review") {
                                        UIApplication.shared.open(writeReviewURL)
                                    }
                                }
                            } header: {
                                Text("Support & Info")
                                    .textCase(nil)
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                            
                            Section {
                                SettingsRow(
                                    icon: "repeat.circle.fill",
                                    iconColor: .green,
                                    title: "Show Onboarding",
                                    subtitle: "See the app intro again"
                                ) {
                                    globalViewModel.isShowingOnboarding = true
                                }
                                
                                SettingsRow(
                                    icon: "arrow.clockwise.circle.fill",
                                    iconColor: .blue,
                                    title: "Restore Purchases",
                                    subtitle: "Recover your Pro subscription"
                                ) {
                                    globalViewModel.restorePurchase()
                                }
                            } header: {
                                Text("App Settings")
                                    .textCase(nil)
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                            
                            Section {
                                SettingsRow(
                                    icon: "hand.raised.fill",
                                    iconColor: .indigo,
                                    title: "Privacy Policy",
                                    subtitle: "How we handle your data"
                                ) {
                                    UIApplication.shared.open(privacyURL)
                                }
                                
                                SettingsRow(
                                    icon: "doc.text.fill",
                                    iconColor: .orange,
                                    title: "Terms of Service",
                                    subtitle: "Usage terms and conditions"
                                ) {
                                    UIApplication.shared.open(termsURL)
                                }
                                
                                SettingsRow(
                                    icon: "questionmark.circle.fill",
                                    iconColor: .teal,
                                    title: "Support",
                                    subtitle: "Get help with TryOn"
                                ) {
                                    UIApplication.shared.open(supportURL)
                                }
                            } header: {
                                Text("Legal")
                                    .textCase(nil)
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .frame(maxWidth: 650)
                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Settings")
            .navigationBarHidden(true)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let onClick: () -> Void
    
    var body: some View {
        Button {
            onClick()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontWeight(.bold)
                }
                Spacer()
            }
            .padding(.vertical, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(GlobalViewModel())
} 