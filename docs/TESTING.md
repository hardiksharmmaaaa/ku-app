# Test Plan — KU Smart Attendance Onboarding App

Doc: **D-010** · Last updated: 20 August 2026

## 1. Scope
- **Unit tests**: add/modify logic in `ku-onboardingTests/`.
- **UI tests**: add/modify flows in `ku-onboardingUITests/`.
- **Manual device tests**: camera flow on physical iPhone.

## 2. Automated

| # | Test | Layer | Status |
|---|---|---|---|
| T-01 | Valid Banner IDs pass | Unit | ✅ |
| T-02 | Invalid Banner IDs fail | Unit | ✅ |
| T-03 | Input normalization (b→B, symbols filtered) | Unit | ✅ |
| T-04 | Future: frame quality gating logic | Unit | Planned |
| T-05 | Future: upload payload serialization | Unit | Planned |
| T-06 | Launch → splash → banner screen | UI | Planned |
| T-07 | Continue disabled until valid input | UI | Planned |

Run: `xcodebuild test -project ku-onboarding.xcodeproj -scheme ku-onboarding`

## 3. Manual device pass (each release)

| # | Scenario | Expected |
|---|---|---|
| M-01 | First launch → camera permission prompt | Dialog shows KU camera string |
| M-02 | Deny permission | Graceful guidance, no crash |
| M-03 | Capture in bright light, single face | 5–10 quality frames captured |
| M-04 | Too dark / multiple faces / too far | Frame not accepted; prompt shown |
| M-05 | Full 6 s elapses before target count | Auto-stop gracefully |
| M-06 | Upload success | Success screen |
| M-07 | Upload failure / retry | Retry available; no data loss |
| M-08 | App killed mid-capture | No partial data persisted |

## 4. Regression after changes
- Re-run unit tests + UI smoke (launch → banner → validation).