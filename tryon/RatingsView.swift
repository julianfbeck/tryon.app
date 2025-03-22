//
//  RatingsView.swift
//  tryon
//
//  Created by Julian Beck on 22.03.25.
//


import SwiftUI
import RatingsKit

struct RatingsView: View {
    var body: some View {
        RatingRequestScreen(
            appId: "6743625964",
            appRatingProvider: MockAppRatingProvider.noRatingsOrReviews,
            primaryButtonAction: {
                // Handle when user has requested to leave a rating
                print("User tapped to leave a rating")
            },
            secondaryButtonAction: {
                // Handle when user decides to rate later
                print("User will rate later")
            },
            onError: { error in
                // Handle any errors that occur
                print("Error occurred: \(error)")
            }
        )
    }
}
