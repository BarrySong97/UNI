# Release Packaging Module

## Purpose

Define a stable Android release packaging strategy that reduces install size while keeping offline TTS capability.

## Boundary

### In Scope
- Android release build type optimization (`minifyEnabled`, `shrinkResources`, Proguard baseline).
- Android release ABI policy for side-load distribution (`arm64-v8a` only).
- Packaging command policy for store and side-load outputs.
- Asset declaration dedup for package size control.

### Out of Scope
- Business logic behavior changes in library/reader/highlight/import modules.
- iOS/macOS/Linux/Windows packaging optimization.
- Replacing offline TTS with online or on-demand runtime delivery.

## Core Flow

1. Build Play Store artifact using:
   - `flutter build appbundle --release`
2. Build side-load artifact using:
   - `flutter build apk --release --target-platform android-arm64`
3. Verify package size and composition when needed:
   - `flutter build apk --release --analyze-size --target-platform android-arm64`

## Key State & Data

- Android release build in `android/app/build.gradle.kts`:
  - `isMinifyEnabled = true`
  - `isShrinkResources = true`
  - `proguard-rules.pro` loaded with default optimized Proguard file.
  - JNI packaging excludes `armeabi-v7a` and `x86_64` shared libraries, keeping arm64 output.
- Flutter assets in `pubspec.yaml`:
  - Keep only assets directly required by app code.
  - `malsami` phonetics lexicon currently requires top-level app assets (`assets/us_gold.json`, `assets/us_silver.json`, `assets/gb_gold.json`, `assets/gb_silver.json`), so these files must remain declared.

## Interaction & Exceptions

- Offline TTS and phonetics must remain available.
- AI phonetics fallback is cache-backed and optional; release packaging must preserve the offline `malsami` assets because the app still resolves phonetics locally before offering any AI fetch path.
- If future requirements include 32-bit devices, `armeabi-v7a` support must be re-enabled explicitly.
- If R8/proguard removes required classes from a plugin, add targeted keep-rules in `android/app/proguard-rules.pro`.

## Acceptance Criteria

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] `flutter build appbundle --release` succeeds.
- [ ] `flutter build apk --release --target-platform android-arm64` succeeds.
- [ ] Side-load APK is arm64-only.
- [ ] APK size decreases versus previous universal APK baseline.

## Non-Goals

- Dynamic feature delivery.
- Runtime model download pipeline redesign.
- Refactoring unrelated application modules.
