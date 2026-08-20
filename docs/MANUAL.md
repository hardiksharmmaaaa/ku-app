# Build & Run Manual — KU Smart Attendance Onboarding App

Manual ID: **D-003** · Last updated: 20 August 2026
Platform target: **iOS** · Build machine: **MacBook with Apple Silicon (M1+) · Xcode 26.6**

---

## 1. Prerequisites

| Requirement | Check |
|---|---|
| macOS with **Apple Silicon (M1/M2/M3/M4)** | `uname -m` → `arm64` |
| **Xcode 26.6+** (free from Mac App Store) | `xcodebuild -version` |
| **Command Line Tools** | `xcode-select -p` |
| A **physical iPhone** (iOS 16+) for camera flow | Camera does not work in Simulator |
| Free/paid Apple Developer account for device install | Settings → Accounts in Xcode |
| Git (optional) | `git --version` |

Fastest verification of the toolchain:

```bash
xcodebuild -version
xcrun simctl list devices available
```

---

## 2. Project Layout

```
KU-app/
└── ku-onboarding/
    ├── ku-onboarding.xcodeproj     # open this in Xcode
    ├── ku-onboarding/              # app source
    │   ├── ku_onboardingApp.swift  # entry point + RootView coordinator
    │   ├── KUTheme.swift           # KU brand palette
    │   ├── Views/                  # SplashView, StudentInfoView
    │   ├── ViewModels/             # StudentInfoViewModel
    │   ├── Models/                 # Student, EnrollmentPayload
    │   └── Assets.xcassets/        # KU colors, official logo, app icon
    ├── ku-onboardingTests/         # unit tests (Banner ID validation)
    └── ku-onboardingUITests/       # UI tests
```

The Xcode project uses **folder-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`) — new `.swift` files dropped into the folder are picked up automatically by Xcode 16+. No manual file registration needed.

---

## 3. Running in the iOS Simulator (no camera)

```bash
# from the ku-onboarding/ directory
xcodebuild -project ku-onboarding.xcodeproj -scheme ku-onboarding \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build
```

Or in Xcode:

1. `open ku-onboarding.xcodeproj`
2. Select the **ku-onboarding** scheme.
3. Pick an iPhone simulator (e.g., iPhone 17 Pro).
4. Press **⌘R** to build & run.

What you can verify in the simulator:

- KU-branded splash → auto-dismisses to the Banner ID screen.
- Banner ID validation (typing, uppercase normalization, format errors).
- Fee available hardware check: **none** — camera UI is a placeholder in this phase.

> See §5 for the vision/backend phases which require real hardware.

---

## 4. Running on a Physical iPhone (camera)

Required for the Face Enrollment screen once Phase 3+ lands.

1. Connect iPhone via USB (or enable **Wireless Debugging**: Device window → Connect via network).
2. In Xcode: **Window → Devices and Simulators** → confirm the device is trusted.
3. Set the signing team (replace the placeholder in the project's Signing & Capabilities).
4. Select your iPhone as the destination, press **⌘R**.
5. The first camera run triggers the **NSCameraUsageDescription** consent dialog
   — the string is already configured in `ku-onboarding/Info.plist`.
6. Accept the dialog and follow the on-screen enrollment prompts.

---

## 5. What Works Today vs. Roadmap

| Screen / Feature | Status | How to exercise |
|---|---|---|
| Splash + KU branding | ✅ Implemented | Simulator or device |
| Banner ID entry + validation | ✅ Implemented | Type `B00123456` → Continue enables |
| Banner ID unit tests | ✅ Implemented | `xcodebuild test` |
| Camera preview + capture | 🕓 Phase 3 | Physical iPhone |
| Vision face-gated capture | 🕓 Phase 4 | Physical iPhone |
| Upload / processing / success | 🕓 Phase 5–6 | Physical iPhone + backend |
| Consent / privacy screen | 🕓 Phase 8 | — |

---

## 6. Running Tests

### Unit tests (Banner ID validation)

```bash
xcodebuild -project ku-onboarding.xcodeproj -scheme ku-onboarding \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug test
```

Covers: valid format, invalid formats, and input normalization (`b001` → `B001`).

### UI tests

Run the `ku-onboardingUITests` target from Xcode (⌘U) on a simulator.

---

## 7. Config & Environment

### Bundle identifier
`fit.ku-onboarding` — set a stable org identifier (e.g., `ae.ac.ku.smartattendance`) for App Store distribution in the target's **Signing & Capabilities**.

### Camera permission
Already in `ku-onboarding/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Khalifa University uses the camera to enroll your face for Smart Attendance verification.</string>
```

### Deployment target
iOS 16+ recommended for clean `async/await` + modern Vision APIs. Current project's `IPHONEOS_DEPLOYMENT_TARGET` is set by the template (26.5); lower it to 16.0 or set per your device fleet.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| Build fails with code-signing error | Set your developer team in Signing & Capabilities, or use `CODE_SIGNING_ALLOWED=NO` for simulator-only builds |
| Simulator shows blank instead of camera | Expected — Simulator has no camera; use a physical device |
| Camera permission never prompts | Uninstall the app, reinstall (permission resets), confirm `NSCameraUsageDescription` present in built Info.plist |
| "No face found" during capture | Improve lighting; face close & centered within the guide oval |
| Upload fails | Verify backend URL in `APIService`, check HTTPS + network entitlement |
| Colors look off vs. brand | Validate against KU Blue `#1C4F9D` in Assets.xcassets |

---

## 9. Deployment (app store / TestFlight)

1. Register the final bundle ID and App icon in App Store Connect.
2. Xcode → **Product → Archive**, then **Distribute App**.
3. Choose **TestFlight** (internal testers) or **App Store Connect** path.
4. Complete export compliance (face/biometric usage) and privacy nutrition labels.

---

## 10. Quick Reference Card

```bash
open ku-onboarding.xcodeproj                                  # Open project
xcodebuild build -project ku-onboarding.xcodeproj \
  -scheme ku-onboarding -sdk iphonesimulator                  # CLI build
xcodebuild test -project ku-onboarding.xcodeproj \
  -scheme ku-onboarding                                       # Run tests
```

---

_More docs: [INDEX.md](INDEX.md) · [docs.md](../docs.md)_