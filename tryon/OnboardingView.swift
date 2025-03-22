import SwiftUI

struct OnboardingView: View {
    @Binding var isShowingOnboarding: Bool
    @State private var currentPage = 0
    
    let onboardingPages = [
        OnboardingPage(
            image: "onboarding1",
            title: "Select Your Photo",
            description: "Upload a clear photo of yourself to try on different clothes"
        ),
        OnboardingPage(
            image: "onboarding2",
            title: "Choose Clothing",
            description: "Select a clothing item you'd like to try on"
        ),
        OnboardingPage(
            image: "onboarding3",
            title: "See the Result",
            description: "View yourself wearing the selected clothing in seconds!"
        )
    ]
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        isShowingOnboarding = false
                    }
                    .padding()
                    .foregroundColor(.secondary)
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        VStack(spacing: 20) {
                            Image(onboardingPages[index].image)
                                .resizable()
                                .scaledToFit()
                                .padding(.horizontal, 20)
                                .frame(height: 300)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                            
                            Text(onboardingPages[index].title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(onboardingPages[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                // Next/Get Started button
                Button(action: {
                    if currentPage < onboardingPages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        isShowingOnboarding = false
                        Plausible.shared.trackPageview(path:"/onboarding/finished")
                            
                    }
                }) {
                    Text(currentPage == onboardingPages.count - 1 ? "Get Started" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
    }
}

// Model for onboarding page content
struct OnboardingPage {
    let image: String
    let title: String
    let description: String
}

#Preview {
    OnboardingView(isShowingOnboarding: .constant(true))
} 
