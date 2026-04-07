# uni

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# UNI

## Android Release APK

Build a release APK:

```bash
flutter pub get
flutter build apk --release
```

Output APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install to a connected Android device or tablet:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

If you only want to rebuild after the first successful setup:

```bash
flutter build apk --release
```

## iOS Release

flutter build ios --release
ios-deploy --bundle build/ios/iphoneos/Runner.app
