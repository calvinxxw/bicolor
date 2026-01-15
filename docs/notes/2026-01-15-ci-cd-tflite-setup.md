# CI/CD Setup for TFLite Binaries

## Overview

TFLite binaries are committed to the repository, so CI/CD pipelines can build directly without additional setup steps.

## Version Information

- Package: `tflite_flutter` v0.12.1
- Runtime: LiteRT 1.4.0
- Tracked in: `flutter_app/pubspec.yaml`

## Build Pipeline Integration

### GitHub Actions Example

```yaml
build:windows:
  runs-on: windows-latest
  steps:
    - uses: actions/checkout@v4

    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.x'

    - name: Build Windows
      run: |
        cd flutter_app
        flutter build windows
```

### GitLab CI Example

```yaml
build:windows:
  image: cirrusci/flutter:stable
  script:
    - cd flutter_app
    - flutter build windows
```

## Troubleshooting

### Missing Binary Warning

If the TFLite binary is missing from `windows/blobs/` or `linux/blobs/`, the build will succeed with a warning. This is expected behavior.

To resolve:
1. Obtain the binary manually (see `flutter_app/README.md`)
2. Place it in the appropriate blobs directory
3. Commit the binary to the repository
