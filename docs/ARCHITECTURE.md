# Architecture Notes — KU Smart Attendance Onboarding App

Doc: **D-004** · Last updated: 20 August 2026

## Pattern: MVVM

```
View ──▶ ViewModel ──▶ (Services: Camera, Vision, Networking)
                          │
                          ▼
                     Models (Student, EnrollmentPayload)
```

- **Views** are thin SwiftUI layouts bound to observable state.
- **ViewModels** own validation and orchestration (e.g., face-capture state machine).
- **Services** wrap Apple frameworks (AVFoundation, Vision, URLSession) so logic is testable without hardware.
- **Models** are plain `Codable` structs shared between layers.

## Current modules (Phases 1–2)

| Module | File | Responsibility |
|---|---|---|
| App coordinator | `ku_onboardingApp.swift` | Splash → Banner ID routing |
| Theme | `KUTheme.swift` | Brand palette + typography constants |
| Splash | `Views/SplashView.swift` | KU hero gradient + white logo |
| Student Info | `Views/StudentInfoView.swift` | Banner ID entry screen |
| VM | `ViewModels/StudentInfoViewModel.swift` | Format validation `^B\d{8}$` + normalization |
| Models | `Models/Student.swift` | Student identity model |
| Models | `Models/EnrollmentPayload.swift` | Upload payload contract |

## Planned modules (Phases 3–6)

- `Services/CameraService.swift` — `AVCaptureSession` wrapper; front camera selection
  (TrueDepth → WideAngle fallback), `AVCaptureVideoDataOutput` sample handling.
- `Services/FaceDetectionService.swift` — Vision requests per frame;
  single-face, centered, sized, `VNDetectFaceCaptureQualityRequest`.
- `Services/ImageProcessingService.swift` — JPEG ~80% compression, face-crop.
- `Services/APIService.swift` — `multipart/form-data` POST `/api/v1/enroll`.
- `ViewModels/FaceEnrollmentViewModel.swift` — capture FSM + progress ring state.

## Concurrency model

- Swift concurrency (`async/await`) for networking and camera sample handling.
- Vision is run on the sample buffer (delegate queue); results hop to `@MainActor`.
- The current project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, keep UI state mutations main-actor isolated and heavy work off-main.

## Testing strategy

- Unit tests target pure logic (Banner ID validation — shipped).
- Face/camera services are thin wrappers; mock sample buffers in tests, run UI flows on a physical device.