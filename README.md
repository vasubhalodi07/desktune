# DeskTune

An Apple StandBy-style desk mode for Android. Prop the phone on your desk and
get a big clock beside a liquid-glass now-playing card that controls Amazon
Music, Spotify and any other media player.

## Features

- **Landscape only** – the app is locked to landscape from the first screen.
- **Clock** – large clock with the date and battery level. Settings lets you
  turn the date on or off, and show seconds on the full-screen clock.
- **Now playing card** – artwork, title and artist, seek bar and
  previous / play-pause / next. The glass colours follow the album artwork.
- **Sliders** – brightness and volume pills below the card.

## Build

```sh
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Release
signing uses `android/app/release.keystore` (not committed).

## First run: enabling media access

DeskTune reads track info and controls playback through Android's
**Notification access**. Apps installed from a file (a file manager, and on
Xiaomi phones `adb install` too) start with that switch locked on Android 13+
("Restricted setting"). The welcome screen detects this and shows the fix:

1. Tap **Open App Info**.
2. Turn on **Allow restricted settings** (at the bottom of the page on
   HyperOS/MIUI, in the ⋮ menu on most other phones).
3. Back in DeskTune, tap **Enable Media Access** and switch it on.

## Project layout

- `lib/features/desk_mode/` – desk screen, clock, music card, sliders
- `lib/features/permission/` – welcome screen and the restricted-settings guide
- `lib/features/settings/` – settings screen
- `lib/services/` – Dart side of the native channels (media, battery, settings)
  and the artwork colour extractor
- `android/app/src/main/kotlin/` – media session, volume and battery bridges
