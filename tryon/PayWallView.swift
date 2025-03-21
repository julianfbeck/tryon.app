//
//  PayWallView.swift
//  tryon
//
//  Created by Julian Beck on 21.03.25.
//


//
//  PayWallView.swift
//  iEmoji
//
//  Created by Julian Beck on 02.01.25.
//
import RevenueCat
import SwiftUI


struct PayWallView: View {
    private let privacyPolicyURL = URL(string: "http://julianbeck.notion.site")!
    private let termsOfServiceURL = URL(string: "https://julianbeck.notion.site/Icon-Generator-d9c6411a7cbb4267a309ef011b8d41e5?pvs=4")!
    
    @EnvironmentObject var globalViewModel: GlobalViewModel
    @State private var isFreeTrialEnabled: Bool = true
    @Environment(\.presentationMode) var presentationMode
    @State private var showCloseButton = false
    @State private var closeButtonProgress: CGFloat = 0.0
    private let allowCloseAfter: CGFloat = 5.0
    @State private var animateGradient = false
    
    var calculateSavedPercentage: Int {
        let annualPrice = globalViewModel.offering?.annual?.storeProduct.pricePerYear?.doubleValue ?? 0
        let weeklyPrice = globalViewModel.offering?.weekly?.storeProduct.pricePerYear?.doubleValue ?? 0
        return Int((100 - ((annualPrice / weeklyPrice) * 100)).rounded())
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue, Color.blue],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button(action: {
                            if showCloseButton {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 2)
                                    .opacity(0.3)
                                    .foregroundColor(.white)
                                
                                Circle()
                                    .trim(from: 0, to: closeButtonProgress)
                                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(-90))
                                
                                Image(systemName: "xmark")
                                    .foregroundColor(showCloseButton ? .white : .white.opacity(0.5))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(width: 30, height: 30)
                        }
                        .disabled(!showCloseButton)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        Text("Unlimited Emojis")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(icon: "face.smiling", text: String(localized:"Create unlimited Emojis"))
                        FeatureRow(icon: "square.and.arrow.down", text:  String(localized:"Download unlimited Packs"))
                        FeatureRow(icon: "arrow.triangle.2.circlepath", text:  String(localized:"Discover awesome Emojis"))
                        FeatureRow(icon: "lock.square.stack", text:  String(localized:"Remove annoying paywalls"))
                        
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                    )
                    .padding(.horizontal)
                    
                    if let offering = globalViewModel.offering,
                       let annual = offering.annual,
                       let weekly = offering.weekly {
                        
                        VStack(spacing: 12) {
                            Button(action: { isFreeTrialEnabled = false }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Premium Annual")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                        Text(weekly.storeProduct.localizedPricePerYear ?? "")
                                            .strikethrough()
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(annual.localizedPriceString) per year")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    }
                                    Spacer()
                                    
                                    Text("SAVE \(calculateSavedPercentage)%")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    
                                    Circle()
                                        .stroke(!isFreeTrialEnabled ? Color.white : Color.white.opacity(0.3), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .fill(!isFreeTrialEnabled ? Color.white : Color.clear)
                                                .frame(width: 16, height: 16)
                                        )
                                }
                                .padding()
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(16)
                            }
                            
                            Button(action: { isFreeTrialEnabled = true }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("3-Day Trial")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                        Text("then \(weekly.localizedPriceString) per week")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    }
                                    Spacer()
                                    Text("TRIAL")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Circle()
                                        .stroke(isFreeTrialEnabled ? Color.white : Color.white.opacity(0.3), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .fill(isFreeTrialEnabled ? Color.white : Color.clear)
                                                .frame(width: 16, height: 16)
                                        )
                                }
                                .padding()
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(16)
                            }
                            
                            Toggle(isOn: $isFreeTrialEnabled) {
                                Text("Enable Free Trial")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .white))
                            .padding(.horizontal)
                            
                            Button(action: {
                                let package = isFreeTrialEnabled ? weekly : annual
                                globalViewModel.purchase(package: package)
                            }) {
                                HStack {
                                    Text(isFreeTrialEnabled ? "Free, then \(weekly.localizedPriceString)" : "Unlock")
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView()
                    }
                    
                    if globalViewModel.isPurchasing {
                        ProgressView()
                    }
                    
                    if let errorMessage = globalViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    
                    HStack(spacing: 16) {
                        Button("Restore") {
                            globalViewModel.restorePurchase()
                        }
                        Link("Terms of Use", destination: termsOfServiceURL)
                        Link("Privacy Policy", destination: privacyPolicyURL)
                    }
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.vertical)
                .frame(maxWidth: min(UIScreen.main.bounds.width, 600))
                .padding(.horizontal)
            }
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue],
                    startPoint: animateGradient ? .topLeading : .bottomLeading,
                    endPoint: animateGradient ? .bottomTrailing : .topTrailing
                )
                .ignoresSafeArea()
            )
        }
        .background(Color.black.opacity(0.1).ignoresSafeArea())
        .onAppear {
            startCloseButtonTimer()
        }
        .interactiveDismissDisabled(!showCloseButton)
    }
    
    private func startCloseButtonTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if closeButtonProgress < 1.0 {
                closeButtonProgress += 0.1 / allowCloseAfter
            } else {
                showCloseButton = true
                timer.invalidate()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 18))
            }
            
            Text(text)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview {
    PayWallView()
}
