# Sketch2Stitch

Flutter app with a Firebase backend. Payments are mocked; no real transactions occur.

## Setup (one-time)

1. **Install Flutter:** https://docs.flutter.dev/get-started/install
2. **Install Android Studio** — open once, use SDK Manager to install the Android SDK, and Device Manager to create an emulator, or connect a physical Android device with USB debugging enabled.
3. **Verify installation:**
   ```bash
   flutter doctor
   ```
   Resolve any items marked with a red ✗ (license issues are usually fixed by running `flutter doctor --android-licenses` and accepting).
4. **Clone the repository:**
   ```bash
   git clone https://github.com/meemmac/Sketch2Stitch.git
   cd Sketch2Stitch
   flutter pub get
   ```
5. **Obtain Firebase config files** from the project owner (collaborator access on the Firebase project is required first):
   - `google-services.json` → place in `android/app/`
   - `GoogleService-Info.plist` (macOS/iOS only) → place in `ios/Runner/`

## Development workflow

```bash
git pull origin main    # fetch latest changes
flutter pub get         # update dependencies if changed
flutter run              # select an emulator or device
```

To submit changes:
```bash
git checkout -b feature/feature-name   # for new work
git add .
git commit -m "description of changes"
git push origin feature/feature-name
```
A Pull Request should then be opened into `main`. Direct pushes to `main` are not permitted.

## Platform notes
- **Android:** supported on both Windows and macOS.
- **iOS:** builds require macOS with Xcode. Windows-based development should target Android only.