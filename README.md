# NEXSUS — Android first

A personal-use assistant app. The current milestone targets Android only; iOS is intentionally postponed.

## Current starter
- Flutter / Dart app entry point in `lib/main.dart`
- Dark neon-purple dashboard
- Greeting that changes with local time
- Live clock with seconds and current date
- Navigation placeholders for Jarvis, Notes, Digital Blat, and Profile

## Complete Android project setup
This repository currently contains the Flutter app source and package manifest. To generate the native Android Gradle wrapper and platform files on a computer with Flutter installed, run from the repository root:

```bash
flutter create . --platforms=android
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

The APK will be created at `build/app/outputs/flutter-apk/app-release.apk`.

Authentication, cloud sync, voice commands, and persistent notes are planned for later milestones and are not implemented in this starter yet.
