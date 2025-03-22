//
//  ContentView.swift
//  tryon
//
//  Created by Julian Beck on 17.03.25.
//

import SwiftUI
import RatingsKit
struct ContentView: View {
    @EnvironmentObject var globalViewModel: GlobalViewModel
    
    var body: some View {
        MainTabView()
            .fullScreenCover(isPresented: $globalViewModel.isShowingPayWall) {
                PayWallView()
            }
            .fullScreenCover(isPresented: $globalViewModel.isShowingOnboarding) {
                OnboardingView(isShowingOnboarding: $globalViewModel.isShowingOnboarding)
                    .onDisappear {
                        if globalViewModel.isFirstLaunch {
                            globalViewModel.isShowingRatings = true
                        } else if !globalViewModel.isPro {
                            globalViewModel.isShowingPayWall = true
                        }
                    }
            }
            .fullScreenCover(isPresented: $globalViewModel.isShowingRatings) {
                RatingRequestScreen(
                    appId: "6743625964",
                    appRatingProvider: MockAppRatingProvider.noRatingsOrReviews,
                    primaryButtonAction: {
                        Plausible.shared.trackPageview(path: "/rate/success")
                    },
                    secondaryButtonAction: {
                        Plausible.shared.trackPageview(path: "/rate/decline")
                        globalViewModel.isShowingRatings = false
                    },
                    onError: { error in
                        Plausible.shared.trackPageview(path: "/rate/error")
                    }
                )
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalViewModel())
}
