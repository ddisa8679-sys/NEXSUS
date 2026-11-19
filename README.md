# NEXSUS (Android first)

Private-use mobile assistant. The first milestone targets Android only.

## Stack
- Flutter / Dart
- Material 3 with a custom dark neon interface

## First milestone
- Responsive home dashboard
- Time-aware greeting and live clock
- Navigation placeholders for Jarvis, Notes, Digital Blat, Profile, and Settings

## Build
Install Flutter and Android Studio, then run:

```bash
flutter pub get
flutter run
flutter build apk --release
```

The release APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.

iOS is intentionally out of scope for this milestone.
