# TryOn - Virtual Clothing Try-On App

TryOn is a Swift iOS application that lets users virtually try on clothing items by selecting a photo of themselves and a clothing item. The app uses a simulated AI backend to create a composite image that shows how the clothing would look on the user.

## Features

- **Virtual Try-On**: Select a photo of yourself and a clothing item to see how it would look
- **History**: View a history of all your previous try-on attempts
- **Modern Swift Architecture**: Utilizes Swift's latest features like async/await and actors
- **Beautiful UI**: Clean, modern interface with consistent branding

## Technical Details

The app is built using:

- SwiftUI for the UI
- The actor concurrency model for thread safety
- Async/await for asynchronous operations
- MVVM architecture pattern
- PhotosUI for image selection

## Project Structure

- **TryOnService.swift**: Actor-based service for the try-on functionality
- **TryOnViewModel.swift**: View model connecting the views to the service
- **ImagePicker.swift**: SwiftUI wrapper for UIKit's image picker
- **TryOnView.swift**: Main view for trying on clothes
- **HistoryView.swift**: View for displaying try-on history
- **MainTabView.swift**: Tab view container for navigation
- **Branding.swift**: App styling and brand constants

## Backend Integration

The app currently uses a mocked backend service to simulate the try-on functionality. In a production environment, this would be replaced with:

1. Image uploading to a real server
2. AI processing for accurate clothing overlay
3. Result image downloading and caching

## Future Improvements

- Implement real backend integration
- Add user accounts to sync history across devices
- Integrate with e-commerce platforms
- Add social sharing capabilities 