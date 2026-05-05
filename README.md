# 🌙 BabySleeper

**A Flutter mobile app that monitors ambient sound levels and triggers alerts when your baby makes noise.**

---

## Overview

BabySleeper is a smart baby monitoring application designed for parents who want to be alerted when their baby cries or makes noise during sleep. The app runs a continuous sound-level monitoring service and triggers customizable alerts—including optional flashlight and lullaby audio—when noise exceeds a set threshold.

### Key Features

✨ **Smart Noise Detection**
- Real-time decibel (dB) monitoring with visual sound meter
- Adjustable sensitivity threshold (30–100 dB)
- 2-second confirmation window to reduce false alarms

🔦 **Multi-Alert System**
- 🔦 **Flash Alert**: Flashlight blinks when baby cries
- 🎶 **Lullaby Alert**: Plays customizable audio files (e.g., white noise, soothing music)
- 📢 Uses Android alarm stream (bypasses silent mode)

🔒 **Safe Mode**
- One-click activation with 1-hour auto-stop timer
- Background monitoring with persistent foreground notification
- Works across Android, iOS, Linux, macOS, and Windows

⚙️ **Customizable Settings**
- Noise sensitivity slider
- Individual toggles for flash and music alerts
- Volume control for lullaby playback (0–100%)
- Audio file picker for custom lullabies

🎨 **Beautiful UI**
- Glass-morphism design with gradient backgrounds
- Smooth animations and visual feedback
- Mobile-optimized responsive layout
- Emoji-enhanced icons for intuitive controls

---

## Tech Stack

- **Framework**: Flutter 3.10.7+
- **Languages**: Dart (18.2%), HTML (59.5%), C++/CMake (19.9%), Swift, C
- **Key Dependencies**:
  - `flutter_foreground_task` – Background service monitoring
  - `noise_meter` – Real-time audio level detection
  - `audioplayers` – Audio playback with alarm stream support
  - `torch_light` – Flashlight control
  - `file_picker` – Audio file selection
  - `permission_handler` – Microphone & camera access
  - `google_fonts` – Custom typography
  - `shared_preferences` – Local data persistence

---

## Platform Support

| Platform | Status |
|----------|--------|
| Android  | ✅ Fully supported |
| iOS      | ✅ Fully supported |
| Web      | ⚠️ Supported |
| Windows  | ✅ Supported |
| macOS    | ✅ Supported |
| Linux    | ✅ Supported |

---

## Installation

### Prerequisites
- Flutter SDK 3.10.7+
- Android SDK 21+ (for Android) / iOS 11+ (for iOS)
- A mobile device or emulator

### Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/abdelwahed-alw/BabySleeper.git
   cd BabySleeper
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

   Or build for specific platforms:
   ```bash
   # Android
   flutter build apk

   # iOS
   flutter build ios

   # Web
   flutter build web
   ```

---

## Usage

### Getting Started

1. **Launch the App**: Open BabySleeper on your device
2. **Grant Permissions**: Allow microphone access when prompted
3. **Configure Settings**:
   - Adjust **Noise Sensitivity** slider to your preferred dB threshold
   - Toggle **Flash Light** and **Lullaby Music** options
   - Select a soothing audio file using the **Select Lullaby** button
   - Set **Lullaby Volume** to your desired level

4. **Activate Safe Mode**:
   - Tap the large circular **🌙/😴** button to start monitoring
   - The button changes to 😴 and shows "Your baby is protected 💤"
   - Monitoring runs for up to 1 hour, then auto-stops

5. **Test the Alert**:
   - Use the **Test Alert** button to verify flash and audio settings
   - Stop the alert with the **Stop Alert** button

---

## Project Structure

```
BabySleeper/
├── lib/
│   ├── main.dart              # App entry point & theme configuration
│   ├── home_page.dart         # Main UI & monitoring logic
│   ├── painters.dart          # Custom paint for animations (star field, sound meter)
│   ├── sound_service.dart     # Sound service handler
│   ├── model/
│   └── widgets/
├── android/                   # Android-specific configuration
├── ios/                       # iOS-specific configuration
├── web/                       # Web assets
├── macos/                     # macOS configuration
├── windows/                   # Windows configuration
├── linux/                     # Linux configuration
├── assets/                    # App icons and images
├── pubspec.yaml               # Flutter dependencies & metadata
└── analysis_options.yaml      # Dart linting rules
```

---

## Architecture

### Monitoring Flow

```
1. App Start
   ↓
2. Request Permissions (microphone, camera, notifications)
   ↓
3. Initialize Foreground Task Service
   ↓
4. User Activates "Safe Mode"
   ↓
5. Start In-App Noise Monitoring (NoiseMeter stream)
   ↓
6. Real-time dB Level Processing
   └─→ If dB > Threshold for 2 seconds: Trigger Alarm
   └─→ Otherwise: Continue monitoring
   ↓
7. Fire Alert (Flash + Music)
   ↓
8. User Stops Alert or Timer Expires (1 hour)
```

### Key Components

- **HomePage** (``home_page.dart``): Central UI with all controls and state management
- **NoiseMeter**: Streams real-time decibel readings
- **AudioPlayer**: Manages lullaby playback on the alarm audio stream
- **TorchLight**: Controls device flashlight
- **FlutterForegroundTask**: Enables background monitoring with persistent notification
- **Painters** (``painters.dart``): Custom canvas drawing for sound meter and star field animations

---

## Permissions Required

- **Microphone**: For sound level detection
- **Camera**: For flashlight control
- **Notifications**: For foreground service alerts

On Android 12+, foreground service permissions are automatically handled by Flutter.

---

## Customization

### Change Alert Threshold
Modify the default threshold in ``home_page.dart``:
```dart
double _threshold = 70.0;  // Default: 70 dB
```

### Adjust Auto-Stop Timer
The app automatically stops monitoring after 1 hour. To change:
```dart
_autoStopTimer = Timer(const Duration(hours: 1), () { ... });
```

### Customize Colors
Edit the theme in ``main.dart``:
```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: const Color(0xFFC9B1FF),  // Primary purple
  secondary: const Color(0xFFFFB6C1),   // Secondary pink
  surface: const Color(0xFFFFF8E7),     // Background cream
),
```

---

## Troubleshooting

### Microphone Not Working
- Ensure microphone permission is granted in app settings
- Restart the app if permission was just granted

### Flashlight Unavailable
- Some devices lack a flashlight; the app gracefully disables this feature
- Flashlight may not work if another app is using it

### Background Service Stops
- Check that battery optimization isn't restricting the app
- Ensure the app isn't force-closed from recent apps

### No Sound from Lullaby
- Verify an audio file is selected in "Select Lullaby"
- Check device volume and ensure silent mode is off
- On iOS, allow the app to play audio in background settings

---

## Development

### Running Tests
```
flutter test
```

### Code Analysis
```
flutter analyze
```

### Building Release Version
```
flutter build apk --release  # Android
flutter build ipa --release  # iOS
```

---

## Permissions & Privacy

BabySleeper:
- ✅ **Never** uploads data to external servers
- ✅ Only accesses microphone for real-time sound detection
- ✅ Only accesses camera/flashlight when alerts are triggered
- ✅ Stores preferences locally using SharedPreferences
- ✅ Is open-source for full transparency

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (``git checkout -b feature/your-feature``)
3. Make your changes
4. Submit a pull request with a clear description

---

## License

This project is provided as-is. See the repository for license details.

---

## Author

**Created by Abdelwahed Abdellaoui**

For questions, feature requests, or bug reports, please open an [issue](https://github.com/abdelwahed-alw/BabySleeper/issues) on GitHub.

---

## Disclaimer

BabySleeper is designed as a supplementary monitoring tool and should not replace professional baby monitors or parental supervision. Always ensure your device is charged and notifications are enabled for optimal safety.

🌙 **Sleep soundly knowing your baby is watched over.** 💤