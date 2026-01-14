# lottery_predictor

A new Flutter project.

## TFLite Select TF Ops setup

The exported models require Select TF ops (Flex) support at runtime.

- Android: `tensorflow-lite-select-tf-ops:2.12.0` is included in `android/app/build.gradle.kts`.
- iOS/macOS: Podfiles include `TensorFlowLiteSelectTfOps`. Run `pod install` on macOS after `flutter pub get`.
- Windows/Linux: Build a TFLite C library with Select TF ops and place it in
  `windows/blobs/libtensorflowlite_c-win.dll` or `linux/blobs/libtensorflowlite_c-linux.so`.
  The platform CMake files copy the library into the app bundle.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
