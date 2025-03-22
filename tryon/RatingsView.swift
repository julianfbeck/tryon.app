import SwiftUI
import RatingsKit

struct RatingsView: View {
    var body: some View {
        RatingRequestScreen(
            appId: "YOUR_APP_ID",
            appRatingProvider: YourAppRatingProvider(),
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