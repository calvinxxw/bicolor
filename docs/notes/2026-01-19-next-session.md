# Next Session Context (Android Flex Validation)

## Goal
Validate TensorFlow Lite Flex/select-ops runtime on Android (and later iOS) for the LSTM-based TFLite models.

## Current Status
- Android SDK installed under `C:\Users\64135\AppData\Local\Android\Sdk`.
- Java 17 installed at `C:\Program Files\Microsoft\jdk-17.0.17.10-hotspot` (required for sdkmanager/Gradle).
- AVD created: `Pixel_5_API_24` (Google APIs x86_64).
- Emulator running as `emulator-5554`.
- `flutter pub get` completed successfully.
- **Blocker:** Gradle downloads fail with `SSLHandshakeException` because the system clock is set to **2026-01-19**.

## Local Code Change
- `flutter_app/android/app/build.gradle.kts`: set `minSdk = 24` (uncommitted).

## Repro Error
- `flutter run -d emulator-5554 --no-pub` fails during Gradle dependency download with TLS handshake errors (Maven/Gradle repositories).

## Next Steps
1. Fix system time (confirm with `Get-Date`).
2. Re-run Android build:
   ```bash
   cd flutter_app
   flutter run -d emulator-5554 --no-pub
   ```
3. Tap **Predict** in the app; expect model load success (no snackbar error, and logs show models loaded).
4. If Android passes, proceed to iOS validation (not started yet).

## Notes
- Android SDK license acceptance was automated; installs succeeded after retries.
- Duplicate `platform-tools` warning exists (`platform-tools` and `platform-tools-2`), but `adb` works.