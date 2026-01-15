# Pre-built TensorFlow Lite Binaries Design

## Goal

Replace local TensorFlow compilation with pre-built binaries for all platforms (Windows, iOS, Android, macOS, Linux).

## Current State

- **iOS/Android/macOS:** Already using pre-built binaries via CocoaPods/Gradle ✓
- **Windows/Linux:** Expecting locally compiled `.dll`/`.so` files (currently missing, manual build failed)

## Solution

Use `tflite_flutter` package's official pre-built binaries:
- Package provides a setup script that downloads platform-specific TFLite binaries with Flex delegate support
- Binaries hosted on tflite_flutter GitHub releases
- Version 0.10.4 includes binaries compatible with TFLite 2.12.0

### Binary Locations After Setup

| Platform | Location |
|----------|----------|
| Windows | `flutter_app/windows/blobs/libtensorflowlite_c-win.dll` |
| Linux | `flutter_app/linux/blobs/libtensorflowlite_c-linux.so` |

## Setup Process

### Developer Setup (one-time per machine)

1. Navigate to Flutter app directory:
   ```bash
   cd flutter_app
   ```

2. Run the tflite_flutter install script:
   ```bash
   dart run tflite_flutter:install
   ```

3. The CMakeLists.txt already handles copying the binary to the app bundle (no changes needed)

### CI/CD Setup

Add the install command to your build pipeline before `flutter build`:
```bash
cd flutter_app
dart run tflite_flutter:install
flutter build windows  # or linux/ios/android
```

### Version Pinning

- The `tflite_flutter` package version (0.10.4) determines which binary version is downloaded
- Updating the package version will get newer binaries

## Required Changes

| File | Change |
|------|--------|
| `flutter_app/README.md` | Update setup instructions - remove manual compilation references, add install script instructions |
| `flutter_app/.gitignore` | Decide: commit binaries (simpler) or ignore them (smaller repo) |
| `docs/notes/2026-01-14-flex-build-context.md` | Archive or delete (documents failed manual build) |

**No changes needed to:**
- CMakeLists.txt (Windows/Linux) - already handles blob copying
- Podfile (iOS/macOS) - already uses pre-built pods
- build.gradle.kts (Android) - already uses pre-built AAR

## Verification

1. **Verify binary download:**
   - Check `windows/blobs/libtensorflowlite_c-win.dll` exists
   - Check `linux/blobs/libtensorflowlite_c-linux.so` exists (if on Linux)

2. **Build test:**
   - Run `flutter build windows` (or `flutter build linux`)
   - Verify no CMake warnings about missing TFLite blob

3. **Runtime test:**
   - Launch the app
   - Verify TFLite model loads without errors
   - Test inference with red/blue ball models

## Potential Issues

- If tflite_flutter install script doesn't include Flex delegate binaries, may need "gpu" or "flex" variant
- Version mismatch between binary and model could cause runtime errors
