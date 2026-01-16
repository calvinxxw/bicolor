# Platform Change: Mobile Only (iOS/Android)

**Date:** 2026-01-16
**Decision:** Drop Windows/Linux support, focus on iOS/Android only

## Reason for Change

The TFLite models use LSTM layers that require TensorFlow Flex delegate support. While this is readily available for mobile platforms through package managers (CocoaPods for iOS, Gradle for Android), desktop platforms (Windows/Linux) require custom-built TFLite binaries with Flex delegate, which is complex and increases binary size significantly (~50MB vs 4.4MB).

## What Changed

### Removed
- `flutter_app/windows/blobs/libtensorflowlite_c-win.dll` (4.4MB Windows binary)
- Windows-specific setup instructions from README

### Updated
- `flutter_app/README.md` - Now clearly states iOS/Android only support
- Added platform-specific build instructions

### Unchanged
- All Flutter Dart code (models, widgets, services, UI) - works on all platforms
- Android configuration - already had Flex delegate support via `tensorflow-lite-select-tf-ops:2.12.0`
- iOS configuration - already had Flex delegate support via `TensorFlowLiteSelectTfOps` pod

## Platform Status

| Platform | Status | Flex Delegate | Notes |
|----------|--------|---------------|-------|
| Android | ✅ Supported | ✅ Via Gradle | Requires Android SDK installation |
| iOS | ✅ Supported | ✅ Via CocoaPods | Requires macOS with Xcode |
| Windows | ❌ Not Supported | ❌ Not available | LSTM models incompatible |
| Linux | ❌ Not Supported | ❌ Not available | LSTM models incompatible |

## Next Steps

To build and test the app:

### Android
1. Install Android Studio and Android SDK
2. Run: `flutter pub get`
3. Build: `flutter build apk`
4. Test on emulator or physical device

### iOS
1. On macOS, install Xcode
2. Run: `flutter pub get && cd ios && pod install && cd ..`
3. Build: `flutter build ios`
4. Test on simulator or physical device

## References

- Original blocker: `docs/notes/2026-01-16-tflite-integration-session.md`
- TFLite Flex delegate: https://www.tensorflow.org/lite/guide/ops_select
- Android TFLite setup: https://www.tensorflow.org/lite/android
- iOS TFLite setup: https://www.tensorflow.org/lite/ios
