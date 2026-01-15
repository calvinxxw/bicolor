# lottery_predictor

A new Flutter project.

## Setup

### Prerequisites
- Flutter SDK (3.x or later)
- Dart SDK (included with Flutter)

### TensorFlow Lite Setup

The app uses `tflite_flutter` package (v0.12.1 with LiteRT 1.4.0) which requires platform-specific binaries with Flex delegate support.

#### Android
`tensorflow-lite-select-tf-ops:2.12.0` is included in `android/app/build.gradle.kts`. No additional setup required.

#### iOS/macOS
Podfiles include `TensorFlowLiteSelectTfOps`. Run `pod install` on macOS after `flutter pub get`.

#### Windows/Linux
Manual binary setup is required:

1. Obtain TFLite C library with Select TF ops support:
   - Download pre-built binaries from TensorFlow releases, or
   - Build from source following TensorFlow Lite documentation

2. Place the binary in the appropriate location:
   - Windows: `windows/blobs/libtensorflowlite_c-win.dll`
   - Linux: `linux/blobs/libtensorflowlite_c-linux.so`

3. Verify the binary includes Flex delegate support (required for Select TF ops)

The CMakeLists.txt automatically copies the TFLite binary to the app bundle during build.

### Building

```bash
flutter build windows  # or linux/ios/android
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
