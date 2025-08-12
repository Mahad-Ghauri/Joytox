---
description: Repository Information Overview
alwaysApply: true
---

# Trace Information

## Summary
Trace is a mobile and web application for live streaming, video reels, and social feed functionality. It's built with Flutter and supports multiple platforms including Android, iOS, and web. The app includes features like live streaming, video reels, user authentication, messaging, and social interactions.

## Structure
- **android/**: Android platform-specific code and configuration
- **ios/**: iOS platform-specific code and configuration
- **lib/**: Main Dart code for the application
  - **app/**: App configuration and setup
  - **auth/**: Authentication screens and logic
  - **components/**: Reusable UI components
  - **controllers/**: State management controllers
  - **home/**: Main app screens and features
  - **models/**: Data models for the application
  - **services/**: Backend services and API integrations
  - **ui/**: UI components and widgets
  - **utils/**: Utility functions and helpers
  - **views/**: Screen views for the application
  - **widgets/**: Reusable widgets
- **assets/**: Application assets (images, translations, SVGs, etc.)
- **test/**: Test files for the application
- **web/**: Web platform-specific code and configuration

## Language & Runtime
**Language**: Dart
**Version**: SDK >=3.0.0 <4.0.0
**Framework**: Flutter
**Build System**: Flutter build system
**Package Manager**: pub (Dart/Flutter package manager)

## Dependencies
**Main Dependencies**:
- **Backend**: parse_server_sdk_flutter, firebase_core, cloud_firestore
- **State Management**: get (GetX)
- **UI/UX**: flutter_svg, cached_network_image, google_fonts
- **Media**: video_player, image_picker, camera, video_editor
- **Live Streaming**: zego_uikit, zego_uikit_prebuilt_live_streaming
- **Authentication**: firebase_auth, google_sign_in, sign_in_with_apple
- **Payments**: purchases_flutter
- **Ads**: google_mobile_ads

**Development Dependencies**:
- flutter_test
- flutter_native_splash
- hive_generator
- build_runner
- flutter_lints

## Build & Installation
```bash
# Install dependencies
flutter pub get

# Run the application in development mode
flutter run

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Build for Web
flutter build web --release
```

## Testing
**Framework**: flutter_test
**Test Location**: test/
**Run Command**:
```bash
flutter test
```

## Platform Configuration
**Android**:
- **Min SDK**: 24
- **Target SDK**: 35
- **Compile SDK**: 36
- **Java Version**: 21

**iOS**:
- **Deployment Target**: iOS 11.0 (implied)
- **Supported Orientations**: Portrait, Landscape Left, Landscape Right

**Web**:
- Standard Flutter web configuration with splash screen support

## Firebase Integration
The app uses multiple Firebase services:
- Firebase Authentication
- Cloud Firestore
- Firebase Messaging
- Firebase Analytics
- Firebase Performance
- Firebase Crashlytics

## Third-Party Services
- Parse Server for backend (Back4App)
- ZegoCloud for live streaming
- Google AdMob for advertisements
- RevenueCat for in-app purchases
- OneSignal for push notifications
- Branch for deep linking