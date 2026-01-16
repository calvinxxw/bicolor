# lottery_predictor

A Flutter lottery prediction app using TensorFlow Lite models.

## Supported Platforms

**iOS and Android only.** The models use LSTM layers requiring TensorFlow Flex delegate, which is not readily available for Windows/Linux desktop builds.

## Setup

### Prerequisites
- Flutter SDK (3.x or later)
- For iOS: Xcode and CocoaPods on macOS
- For Android: Android Studio and Android SDK

### TensorFlow Lite Setup

The app uses `tflite_flutter` package (v0.12.1) with models requiring Flex delegate support.

#### Android
1. Install Android Studio and Android SDK
2. The required `tensorflow-lite-select-tf-ops` dependency is already configured in `android/app/build.gradle.kts`
3. Run: `flutter pub get`
4. Build: `flutter build apk` or `flutter build appbundle`

#### iOS
1. Requires macOS with Xcode installed
2. The required `TensorFlowLiteSelectTfOps` pod is already configured
3. Run: `flutter pub get && cd ios && pod install && cd ..`
4. Build: `flutter build ios`

### Building

```bash
# Android
flutter build apk          # Debug APK
flutter build appbundle    # Release bundle for Play Store

# iOS (macOS only)
flutter build ios
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
