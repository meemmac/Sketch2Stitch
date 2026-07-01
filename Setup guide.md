# Sketch2Stitch — Full Setup Guide

This guide walks you through setting up the project from zero, step by step. Works on both Windows and macOS unless noted otherwise. Follow the steps in order — each one builds on the last.

---

## Step 1: Install Flutter

Flutter is the framework this app is built with.

**macOS (recommended way):**
```bash
brew install --cask flutter
```
If you don't have Homebrew yet, install it first from https://brew.sh (follow the one-line install command on their homepage), then run the line above.

**Windows:**
Download the Flutter SDK zip from https://docs.flutter.dev/get-started/install/windows, unzip it to a permanent folder (e.g. `C:\src\flutter`), then add `C:\src\flutter\bin` to your system PATH (search "Environment Variables" in Windows search → Edit the Path variable → add the folder).

**Check it worked:**
```bash
flutter --version
```
You should see a version number print out. If you get "command not found," the PATH isn't set correctly — restart your terminal and try again.

---

## Step 2: Install Android Studio

This gives you the Android SDK (needed to build the app) and tools to manage your device/emulator. You will **not** write code here — just use it for setup.

1. Download from https://developer.android.com/studio (pick the correct version for your machine — see "Which chip do I have" note below for Mac).
2. Open the installer and run through the **Setup Wizard** → choose **Standard** installation → let it download everything (takes several minutes, needs internet).
3. Once it opens to the welcome screen, go to **More Actions → SDK Manager** and confirm at least one Android SDK version has a checkmark next to it.
4. Close Android Studio. You're done with it for now.

**Mac only — which chip do I have?**
Run `uname -m` in terminal. `arm64` = Apple Silicon (M1/M2/M3/M4). `x86_64` = Intel. Download the matching version.

**Accept Android licenses (required, one-time):**
```bash
flutter doctor --android-licenses
```
Type `y` and press Enter for each prompt until it finishes.

**Verify everything:**
```bash
flutter doctor
```
The Android toolchain line should now show a green ✓. If Xcode/CocoaPods/Chrome show warnings — ignore them, they're not needed unless you're building for iOS or web.

---

## Step 3: Connect a Real Android Device (recommended over an emulator)

Using your own phone is faster and more reliable than an emulator.

1. On your Android phone: go to **Settings → About Phone** → tap **Build Number** 7 times in a row. This unlocks Developer Options.
2. Go to **Settings → System → Developer Options** → turn on **USB Debugging**.
3. Plug your phone into your computer with a USB cable.
4. Your phone will pop up a prompt: **"Allow USB debugging?"** → tap **Allow**.
5. Check your computer sees it:
```bash
flutter devices
```
Your phone's name should appear in the list. If it doesn't show up, unplug/replug the cable, or try a different cable (some cables are charge-only).

*(Prefer an emulator instead? In Android Studio: More Actions → Virtual Device Manager → Create Device → pick a phone model → pick a system image → Finish. Then it appears in `flutter devices` too, no cable needed.)*

---

## Step 4: Install Git

**macOS:** usually pre-installed. Check with `git --version`. If missing, install via `brew install git`.
**Windows:** download from https://git-scm.com/downloads and install with default options.

---

## Step 5: Clone the Project

```bash
git clone https://github.com/meemmac/Sketch2Stitch.git
cd Sketch2Stitch
```

---

## Step 6: Install Project Dependencies

```bash
flutter pub get
```
This downloads all the packages the app needs (Firebase, etc.). Expect it to run for a few seconds to a minute.

---

## Step 7: Get Firebase Config Files

Ask the project owner to add you as a collaborator on the Firebase project console. Once added:

1. Go to Firebase Console → Project Settings → Your Apps
2. Download `google-services.json` (Android) → place it inside `android/app/` in your project folder
3. (Mac users only, for iOS builds) Download `GoogleService-Info.plist` → place it inside `ios/Runner/`

These files are intentionally excluded from Git (`.gitignore`) — everyone downloads their own copy from Firebase Console.

---

## Step 8: Verify Everything Works (Test Screen)

Before touching any real app code, confirm your whole setup — Flutter, Android SDK, and your phone connection — actually works end to end.

1. Open `lib/main.dart` in your editor.
2. Temporarily replace its entire content with the test file shown below (or ask a teammate for `main_test.dart` and swap it in). This is a simple screen with no Firebase, no database — just plain Flutter UI with a tap counter, so if it works, your toolchain is fine.
3. Save the file.
4. Confirm your phone is detected:
```bash
flutter devices
```
Your phone's name should appear in the list.
5. Run it:
```bash
flutter pub get
flutter run
```
If more than one device shows up, type the number for your phone and press Enter.

**What to expect:**
- First run takes a few minutes (building the app from scratch)
- Your phone briefly shows an "Installing..." notification
- A purple welcome screen appears on your phone: a clothing icon, "Sketch2Stitch" title, and a "Tap to test" button
- Tap the button — a counter should go up each time (confirms the app is actually interactive, not a frozen screenshot)
- Terminal stays open while the app runs — press `r` to hot-reload after any code change, or `q` to quit

**If this screen shows up and the button works — your entire setup is confirmed working.** You can now safely start writing real app code. Once you're ready to move to actual development, restore the original `main.dart` (or pull the latest version from `main` branch) before continuing.

**If something goes wrong here**, don't move forward — fix it first using the Troubleshooting table below, since every future run depends on this working.

## Step 9: Run the App (Normal Development)

Once verified, for regular day-to-day development:
```bash
flutter run
```
Any code changes you make while it's running can be seen instantly by pressing `r` in the terminal (hot reload) — no need to restart.

---

## Daily Workflow (after setup is done)

Every time you sit down to work:
```bash
git pull origin main
flutter pub get
flutter run
```

When you finish a piece of work:
```bash
git checkout -b feature/your-feature-name    # only when starting something new
git add .
git commit -m "describe what you changed"
git push origin feature/your-feature-name
```
Then open a Pull Request on GitHub to merge into `main`. Do not push directly to `main`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter: command not found` | Flutter's folder isn't in your PATH — recheck Step 1 |
| Android toolchain shows ✗ | Run `flutter doctor --android-licenses` again |
| Phone not detected in `flutter devices` | Re-check USB debugging is on, try another cable/USB port |
| `flutter pub get` fails | Check your internet connection, try again |
| App won't launch on phone | Run `flutter clean` then `flutter pub get` then `flutter run` again |
| Firebase errors on launch | Confirm `google-services.json` is in `android/app/`, not the project root |

---

## Platform Notes
- **Android:** works for everyone, Windows or Mac.
- **iOS:** only possible on a Mac with Xcode installed. Windows users should just build/test on Android — that's expected and totally fine for this project.