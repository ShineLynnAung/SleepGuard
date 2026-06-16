# SleepGuard

Automatic sleep detection and device lock for Android.

## Overview

SleepGuard monitors camera visibility and user inactivity to detect when you may have fallen asleep while using your phone. When either condition is met, a warning countdown overlay appears. If not dismissed, the device locks automatically. All detection runs at the native level and works even when the app is minimized.

## Detection Logic

SleepGuard uses two independent timers. When either reaches its limit, the warning triggers:

| Condition | Timeout | Mechanism |
|-----------|---------|-----------|
| Camera covered/dark | 30 seconds | Native Camera2 API brightness analysis |
| No touch interaction | 5 minutes | Inactivity timer (resets on any touch) |

Both timers run in a foreground service and continue monitoring even when the app is in the background (e.g., when using other apps).

The warning countdown (default: 15 seconds) can be cancelled by:
- Tapping the "I'm Awake" button
- Touching anywhere on the screen

After the countdown reaches zero, the device locks automatically via DevicePolicyManager.

## Architecture

```
lib/
├── main.dart                          # Entry point
├── app.dart                           # App widget with routing
├── core/
│   ├── constants.dart                 # App-wide constants
│   ├── theme.dart                     # Material 3 dark theme
│   └── routes.dart                    # GoRouter configuration
├── domain/
│   ├── enums/
│   │   ├── sleep_signal.dart          # Sleep signal types
│   │   └── monitor_state.dart         # Monitoring states
│   └── models/
│       ├── detection_config.dart      # Configuration model
│       ├── detection_event.dart       # Detection event model
│       └── sleep_score.dart           # Score calculation model
├── data/
│   ├── repositories/
│   │   ├── settings_repository.dart   # Settings persistence
│   │   └── analytics_repository.dart  # Analytics persistence
│   └── services/
│       ├── monitor_service.dart       # Core monitoring logic
│       ├── camera_service.dart        # Native camera brightness analysis
│       ├── inactivity_service.dart    # Touch inactivity timer
│       └── platform_service.dart      # Native Android bridge
└── presentation/
    ├── providers/
    │   ├── settings_provider.dart     # Settings state
    │   ├── monitor_provider.dart      # Monitoring state
    │   ├── analytics_provider.dart    # Analytics state
    │   └── warning_provider.dart      # Warning overlay state
    ├── screens/
    │   ├── home_screen.dart           # Main monitoring + warning overlay
    │   ├── settings_screen.dart       # Configuration screen
    │   ├── analytics_screen.dart      # Statistics screen
    │   └── onboarding_screen.dart     # Initial setup wizard
    └── widgets/
        └── stat_card.dart             # Analytics stat card

android/app/src/main/kotlin/com/sleepguard/app/
├── MainActivity.kt                    # Flutter activity + method/event channels
├── DeviceAdminReceiver.kt             # Device admin broadcast receiver
├── ForegroundMonitorService.kt        # Foreground service for bg monitoring
└── CameraBrightnessAnalyzer.kt        # Native Camera2 brightness analysis
```

## Tech Stack

- **Flutter** with Dart (latest stable)
- **Riverpod** - State management
- **GoRouter** - Declarative routing
- **Material 3** - Design system (dark theme)
- **Android Camera2 API** - Native camera brightness analysis
- **shared_preferences** - Persistent settings
- **Kotlin** - Native Android integration
- **DevicePolicyManager** - Screen lock capability

## Prerequisites

- Flutter SDK (latest stable)
- Android Studio or IntelliJ IDEA
- Android device or emulator running API 26+
- USB debugging enabled (for physical device)

## Setup

```bash
# Clone the repository
git clone <repo-url> sleep_guard
cd sleep_guard

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

## Configuration

Settings are available from the Settings screen:

| Setting | Default | Range |
|---------|---------|-------|
| Inactivity Timeout | 5 minutes | 1-30 minutes |
| Warning Countdown | 15 seconds | 5-60 seconds |
| Camera Detection | Enabled | On/Off |

## Permissions

During onboarding, SleepGuard requests:

1. **Device Admin** - Required to lock the screen
2. **Camera** - Front camera for blocked/dark detection

## Build Release

```bash
# Generate a signing key (first time only)
keytool -genkey -v -keystore upload-keystore.jks \
  -alias upload -keyalg RSA -keysize 2048 \
  -validity 10000

# Build release APK
flutter build apk --release

# Build release App Bundle (recommended for Play Store)
flutter build appbundle --release
```

The release APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## License

MIT
