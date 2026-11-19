# NEXSUS — Android first

Personal-use Android assistant. iOS is postponed.

## Current app
- Neon-purple authentication screen: sign in and create account
- Firebase email/password authentication adapter
- Email verification after registration
- Password reset email
- Dashboard with live clock and navigation placeholders

## Generate the Android platform

Run from the repository root on a computer with Flutter installed:

```bash
flutter create . --platforms=android
```

## Connect Firebase Authentication

1. Create a Firebase project in the Firebase Console.
2. Add an Android app to that Firebase project. Use the Android application ID from `android/app/build.gradle` (or `android/app/build.gradle.kts`) after generating the Android platform.
3. Install the Firebase CLI and FlutterFire CLI, then run:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

4. In the Firebase Console, open Authentication → Sign-in method and enable **Email/Password**.
5. Download/setup the Android Firebase configuration using FlutterFire. Make sure the generated Android configuration and Google Services Gradle plugin are present.
6. Fetch packages and run:

```bash
flutter pub get
flutter run
```

The app initializes Firebase at startup. If Firebase configuration is missing, the UI still opens and displays a setup message when an authentication action is attempted.

## Authentication behavior

- Registration uses email and password and stores the nickname as the Firebase display name.
- Firebase sends an email verification **link**, not a numeric one-time code.
- “Forgot password?” sends Firebase's password-reset email link.
- Sign-in currently uses the email address and password.

The app source is in `lib/`. The native Android project and Firebase project configuration must be generated/configured locally; credentials and project-specific configuration are intentionally not fabricated or committed.

## Build a release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.
