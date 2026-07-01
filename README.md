# Sketch2Stitch

A mobile app connecting Customers, Retailers, and Tailors — browse fabric/accessories, get a virtual trial preview, sketch custom designs, and manage the full order-to-delivery lifecycle with mock payments.

**Tech Stack**
- Frontend: Flutter (Custom Painter for sketch board)
- Backend/Auth/DB: Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging)
- AI: Gemini API (Virtual Trial preview)
- Payments: Mock only (no real transactions)

---

## 1. Prerequisites (Windows & macOS)

Install these before touching the project:

| Tool | Purpose | Install Link |
|---|---|---|
| Flutter SDK | Build the app | https://docs.flutter.dev/get-started/install |
| Git | Version control | https://git-scm.com/downloads |
| Node.js (LTS) | Needed for Firebase CLI | https://nodejs.org |
| Firebase CLI | Deploy Cloud Functions, manage project | run `npm install -g firebase-tools` after Node is installed |
| Android Studio | Android emulator + SDK | https://developer.android.com/studio |
| Xcode (macOS only) | iOS simulator/build | Mac App Store |
| VS Code or Antigravity | Code editor | your choice |

**Windows-specific:** Android is your primary target. You cannot build/run the iOS version on Windows — that's only possible on a Mac. Make sure Android Studio's emulator is set up (AVD Manager → create a device).

**macOS-specific:** Install CocoaPods for iOS dependencies:
```bash
sudo gem install cocoapods
```

Check your Flutter setup is healthy on either OS:
```bash
flutter doctor
```
Fix anything marked with a red ✗ before proceeding.

---

## 2. Clone the Repo

```bash
git clone https://github.com/meemmac/Sketch2Stitch.git
cd Sketch2Stitch
```

---

## 3. Install Dependencies

```bash
flutter pub get
```

For Cloud Functions:
```bash
cd functions
npm install
cd ..
```

---

## 4. Firebase Setup (one-time, per developer machine)

1. Ask the project owner to add you as a collaborator on the Firebase project (Firebase Console → Project Settings → Users and permissions).
2. Log in to Firebase CLI:
   ```bash
   firebase login
   ```
3. Link your local project:
   ```bash
   firebase use --add
   ```
   Select the shared Firebase project when prompted.
4. Download platform config files from Firebase Console and place them:
   - Android: `google-services.json` → `android/app/`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`

   *(These files are git-ignored on purpose — never commit them. Each teammate downloads their own copy from console, they're identical per-project so this is safe to share via Firebase Console access.)*

5. If using FlutterFire CLI (recommended, simpler):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This auto-generates `firebase_options.dart` and wires up both platforms.

---

## 5. Run the App

```bash
flutter run
```
Select your emulator/device when prompted.

---

## 6. Run Cloud Functions Locally (optional, for testing timers/logic)

```bash
cd functions
npm run build
firebase emulators:start
```

---

## 7. Branching & Workflow

- `main` — stable, working code only
- Create a feature branch per task: `git checkout -b feature/login-screen`
- Push and open a Pull Request before merging into `main`
- Pull latest `main` before starting new work: `git pull origin main`

---

## 8. Common Issues

| Problem | Fix |
|---|---|
| `flutter doctor` shows Android license issues | `flutter doctor --android-licenses` |
| CocoaPods errors on Mac | `cd ios && pod install --repo-update` |
| Firebase permission denied | Confirm you were added as a collaborator on the Firebase project |
| Emulator not detected | Open Android Studio → Device Manager → start emulator manually first |

---

## 9. Project Structure

See `docs/DIRECTORY_GUIDE.md` for a full breakdown of what code belongs in each file/folder.
