# KU Smart Attendance — Onboarding App

![KU Blue](https://img.shields.io/badge/Brand-KU%20Blue%20%231C4F9D-1C4F9D)

Khalifa University **face-enrollment onboarding app** for iOS. A student enters their Banner ID, the app captures 5–10 quality-gated face frames on-device, and uploads them to a backend to generate/store their face embedding for attendance recognition.

## Scope

This app only **enrolls** — it registers a face against a Banner ID. Recognition/matching happens in a separate attendance system.

## Status

- ✅ Phase 1 — Xcode scaffold, SwiftUI navigation, KU theme (official logo, blue `#1C4F9D` palette, app icon)
- ✅ Phase 2 — Banner ID entry + validation (tested)
- 🕓 Phase 3+ — camera, Vision face gating, upload, success screens (see [docs.md](docs.md))

## Quick start

```bash
open ku-onboarding.xcodeproj     # then ⌘R in Xcode
```

Or from the CLI:

```bash
xcodebuild -project ku-onboarding.xcodeproj -scheme ku-onboarding \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Camera flow requires a **physical iPhone** (Simulator has no camera).

## Documentation

| Doc | Purpose |
|---|---|
| [docs.md](docs.md) | Master development plan |
| [docs/INDEX.md](docs/INDEX.md) | Document & asset tracker (keep current!) |
| [docs/MANUAL.md](docs/MANUAL.md) | Build & run manual, troubleshooting |
| [docs/BRANDING.md](docs/BRANDING.md) | KU brand usage |

## Branding

Official KU logo (`KULogo`, `KULogoWhite`) and KU Blue `#1C4F9D` color assets ship in the asset catalog. Refer to KU Communications before public release.

## Repo layout

```
ku-onboarding.xcodeproj   # Xcode project (folder-synced groups)
ku-onboarding/            # App source (Views, ViewModels, Models, Theme, Assets)
ku-onboardingTests/       # Unit tests
ku-onboardingUITests/     # UI tests
docs/                     # Documentation suite
```