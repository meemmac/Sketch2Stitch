# Sketch2Stitch

Flutter app + Firebase backend. Mock payments, no real money.

## Setup (one-time)

1. **Install Flutter:** https://docs.flutter.dev/get-started/install (pick your OS)
2. **Install Android Studio** → open it once → SDK Manager (install Android SDK) → Device Manager (create/start an emulator), or just plug in a real Android phone with USB debugging on.
3. **Check everything's OK:**
   ```bash
   flutter doctor
   ```
   Fix any red ✗ it shows (usually licenses — run `flutter doctor --android-licenses` and accept).
4. **Clone the repo:**
   ```bash
   git clone https://github.com/meemmac/Sketch2Stitch.git
   cd Sketch2Stitch
   flutter pub get
   ```
5. **Get Firebase config files** from whoever owns the Firebase project (ask to be added as a collaborator first):
   - `google-services.json` → put in `android/app/`
   - (Mac only, for iOS) `GoogleService-Info.plist` → put in `ios/Runner/`


## Every time you work on it

```bash
git pull origin main        # get latest changes
flutter pub get              # in case dependencies changed
flutter run                  # pick your emulator/device when it asks
```

When done with a change:
```bash
git checkout -b feature/your-thing   # only if starting new work
git add .
git commit -m "what you did"
git push origin feature/your-thing
```
Then open a Pull Request on GitHub into `main`. Don't push straight to `main`.

## Platform notes
- **Android:** everyone can build/run this, Windows or Mac.
- **iOS:** only possible on a Mac. If you're on Windows, just build/test Android — that's expected and fine.