# Pre-built TFLite Binaries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace local TensorFlow compilation with pre-built binaries from tflite_flutter package for Windows/Linux platforms.

**Architecture:** Use tflite_flutter package's install script to download platform-specific binaries. Update documentation to reflect new setup process. Remove references to failed manual compilation approach.

**Tech Stack:** Flutter, tflite_flutter package (0.10.4), Dart

---

## Task 1: Run Binary Installation Script

**Files:**
- Verify: `flutter_app/windows/blobs/` (directory will be created)
- Verify: `flutter_app/pubspec.yaml` (check tflite_flutter version)

**Step 1: Check current tflite_flutter version**

Run: `cd flutter_app && type pubspec.yaml | findstr tflite_flutter`
Expected: Should show version 0.10.4 or similar

**Step 2: Run the install script**

Run: `cd flutter_app && dart run tflite_flutter:install`
Expected: Script downloads binaries and creates `windows/blobs/` directory

**Step 3: Verify binary downloaded**

Run: `cd flutter_app && dir windows\blobs\libtensorflowlite_c-win.dll`
Expected: File exists with size > 0 bytes

**Step 4: Commit binary installation**

```bash
cd flutter_app
git add windows/blobs/libtensorflowlite_c-win.dll
git commit -m "chore: add pre-built TFLite binary for Windows"
```

---

## Task 2: Update Flutter App README

**Files:**
- Modify: `flutter_app/README.md`

**Step 1: Read current README**

Read the file to understand current structure and locate setup instructions section.

**Step 2: Update setup instructions**

Replace manual compilation references with:

```markdown
## Setup

### Prerequisites
- Flutter SDK (3.x or later)
- Dart SDK (included with Flutter)

### TensorFlow Lite Setup

1. Install TFLite binaries:
   ```bash
   cd flutter_app
   dart run tflite_flutter:install
   ```

2. Verify installation:
   - Windows: Check `windows/blobs/libtensorflowlite_c-win.dll` exists
   - Linux: Check `linux/blobs/libtensorflowlite_c-linux.so` exists

The `tflite_flutter` package (v0.10.4) automatically downloads platform-specific binaries with Flex delegate support. No manual TensorFlow compilation required.

### Building

```bash
flutter build windows  # or linux/ios/android
```

The CMakeLists.txt automatically copies the TFLite binary to the app bundle.
```

**Step 3: Remove manual compilation references**

Search for and remove any sections mentioning:
- Manual TensorFlow compilation
- Building TensorFlow from source
- Custom TFLite build instructions

**Step 4: Commit README updates**

```bash
git add flutter_app/README.md
git commit -m "docs: update setup instructions for pre-built TFLite binaries"
```

---

## Task 3: Update .gitignore Configuration

**Files:**
- Modify: `flutter_app/.gitignore`

**Step 1: Read current .gitignore**

Check if `windows/blobs/` or `linux/blobs/` are currently ignored.

**Step 2: Decide on binary handling**

**Option A (Recommended): Commit binaries**
- Simpler for developers (no setup step)
- Larger repo size (~50MB per platform)
- Remove any blob ignore rules

**Option B: Ignore binaries**
- Smaller repo
- Requires `dart run tflite_flutter:install` in setup
- Add ignore rules

**Step 3: Update .gitignore based on decision**

If committing binaries (Option A):
```gitignore
# Remove or comment out any lines like:
# windows/blobs/
# linux/blobs/
```

If ignoring binaries (Option B):
```gitignore
# TFLite binaries (download via: dart run tflite_flutter:install)
windows/blobs/
linux/blobs/
```

**Step 4: Commit .gitignore changes**

```bash
git add flutter_app/.gitignore
git commit -m "chore: configure .gitignore for TFLite binaries"
```

---

## Task 4: Archive Failed Build Documentation

**Files:**
- Delete: `docs/notes/2026-01-14-flex-build-context.md`

**Step 1: Verify file exists**

Run: `dir docs\notes\2026-01-14-flex-build-context.md`
Expected: File exists

**Step 2: Review file content**

Read the file to confirm it documents the failed manual build approach.

**Step 3: Delete the file**

Run: `git rm docs/notes/2026-01-14-flex-build-context.md`
Expected: File staged for deletion

**Step 4: Commit deletion**

```bash
git commit -m "docs: remove obsolete manual TFLite build documentation"
```

---

## Task 5: Build and Verify

**Files:**
- Test: `flutter_app/` (entire app)

**Step 1: Clean build artifacts**

Run: `cd flutter_app && flutter clean`
Expected: Removes build/ directory

**Step 2: Build Windows app**

Run: `cd flutter_app && flutter build windows`
Expected: Build succeeds without CMake warnings about missing TFLite blob

**Step 3: Verify binary in build output**

Run: `dir flutter_app\build\windows\x64\runner\Release\libtensorflowlite_c-win.dll`
Expected: File exists (copied by CMakeLists.txt)

**Step 4: Run app and test inference**

Run: `cd flutter_app\build\windows\x64\runner\Release && .\lottery.exe`
Expected:
- App launches without errors
- TFLite model loads successfully
- Red/blue ball inference works

---

## Task 6: Update CI/CD Documentation

**Files:**
- Create: `docs/notes/2026-01-15-ci-cd-tflite-setup.md`

**Step 1: Create CI/CD setup guide**

```markdown
# CI/CD Setup for TFLite Binaries

## Build Pipeline Integration

Add the TFLite install step before building:

### GitHub Actions Example
```yaml
- name: Install TFLite binaries
  run: |
    cd flutter_app
    dart run tflite_flutter:install

- name: Build Windows
  run: |
    cd flutter_app
    flutter build windows
```

### GitLab CI Example
```yaml
build:windows:
  script:
    - cd flutter_app
    - dart run tflite_flutter:install
    - flutter build windows
```

## Version Management

- Binary version is determined by `tflite_flutter` package version in `pubspec.yaml`
- Current version: 0.10.4 (TFLite 2.12.0 compatible)
- To update: Bump package version and re-run install script
```

**Step 2: Commit CI/CD documentation**

```bash
git add docs/notes/2026-01-15-ci-cd-tflite-setup.md
git commit -m "docs: add CI/CD setup guide for TFLite binaries"
```

---

## Verification Checklist

After completing all tasks:

- [ ] Binary exists: `flutter_app/windows/blobs/libtensorflowlite_c-win.dll`
- [ ] README updated with new setup instructions
- [ ] Manual compilation references removed
- [ ] .gitignore configured for binary handling
- [ ] Obsolete build documentation deleted
- [ ] Windows build succeeds without warnings
- [ ] App launches and TFLite inference works
- [ ] CI/CD documentation created
- [ ] All changes committed with clear messages

## Rollback Plan

If issues occur:
1. Revert commits: `git revert HEAD~6..HEAD`
2. Remove binaries: `git rm flutter_app/windows/blobs/*`
3. Restore manual build docs: `git checkout HEAD~6 -- docs/notes/2026-01-14-flex-build-context.md`
