# Khalifa University — Smart Attendance Onboarding App

**Full Development Plan** · Version 1.0 · 20 August 2026

> Subject to approval by Khalifa University Communications & Business Development for official logo use. All brand colors verified against the official KU logo asset (KU Blue `#1C4F9D`).

---

## 1. Document Purpose

This is the master planning document for the **KU Smart Attendance — Onboarding App**. It captures the product scope, user flow, screen-by-screen UX, architecture, technology stack, backend pipeline, privacy/compliance requirements, branding, and the phased build roadmap.

Related documents are tracked in [docs/INDEX.md](docs/INDEX.md), and step-by-step build/run instructions live in [docs/MANUAL.md](docs/MANUAL.md).

---

## 2. App Concept Summary

A lightweight iOS onboarding app with a firm scope boundary: **enroll a student's face against their Banner ID** so a separate attendance-taking system (kiosk, classroom camera) can later recognize them.

| Deliverable | Detail |
|---|---|
| **Screen 1** | Student Information — Banner ID entry + validation |
| **Screen 2** | Face Enrollment — front camera captures 5–10 quality-gated frames over ~5–6 s |
| **Output** | Upload frames + Banner ID to backend for face-embedding generation and storage |

This app does **not** do recognition, matching, or attendance — it only enrolls.

---

## 3. User Flow

```
Launch App
   │
   ▼
Splash / KU Branding Screen          (implemented — KU logo + brand gradient)
   │
   ▼
Student Information Screen           (implemented — Banner ID + validation)
    ├─ Banner ID (e.g., 100012345)
    ├─ Format validation (^1000\d{5}$)
   └─ Continue button (disabled until valid)
   │
   ▼
Camera Permission Prompt (iOS system dialog, first launch)
   │
   ▼
Face Enrollment / Capture Screen     (Phase 3–4)
   ├─ Live front-camera preview (TrueDepth → WideAngle fallback)
   ├─ Face oval guide overlay
   ├─ 5–10 frames over 5–6 s with pose prompts
   ├─ Vision-based quality gating (single face, lighting, size, blur)
   └─ Progress ring / frame counter
   │
   ▼
Processing / Upload Screen           (Phase 5–6)
   ├─ JPEG ~80% frames + Banner ID via multipart POST
   └─ Progress spinner + retry on failure
   │
   ▼
Success Screen                       (Phase 6)
   ├─ "You're enrolled!" KU-themed confirmation
   └─ Option to redo capture
```

---

## 4. Screen-by-Screen UX Notes

### 4.1 Student Information Screen ✅ (Phase 2 — implemented)
- Single large centered input, Banner ID only.
- `TextField` with `.keyboardType(.asciiCapable)` and autocapitalization normalized to uppercase.
- Client-side validation: `^1000\d{5}$` (leading `1000` + 5 digits). Adjust to KU's actual format if different.
- "Continue" enabled only when `isValid`.
- Helper caption: "Your Banner ID is printed on your student card and available in MyKU."

### 4.2 Face Enrollment Screen (Phase 3–4)
- `AVCaptureSession`, front camera via `.builtInTrueDepthCamera` → fallback `.builtInWideAngleCamera`.
- SwiftUI `Shape` oval/face-guide overlay.
- Vision framework requests per frame: `VNDetectFaceRectanglesRequest`, `VNDetectFaceLandmarksRequest`, `VNDetectFaceCaptureQualityRequest` gate each frame.
- A frame is accepted only when: exactly one face, centered, reasonably sized, good capture quality.
- Stop on target frame count **or** 6-second timeout, whichever comes first.

### 4.3 Processing / Upload (Phase 5–6)
- Frames compressed to JPEG ~80% before upload.
- Upload `multipart/form-data` with Banner ID + frames.
- Progress UI + retry on failure; clear frames from memory after success.

---

## 5. Recommended Architecture — MVVM

```
ku-onboarding/
├── App/
│   └── ku_onboardingApp.swift          (entry + RootView coordinator)
├── Views/
│   ├── SplashView.swift               ✅ KU-branded splash
│   ├── StudentInfoView.swift          ✅ Banner ID entry
│   ├── FaceEnrollmentView.swift       (Phase 3–4)
│   ├── ProcessingView.swift           (Phase 5–6)
│   └── SuccessView.swift              (Phase 6)
├── ViewModels/
│   ├── StudentInfoViewModel.swift     ✅ Banner ID validation (testable)
│   └── FaceEnrollmentViewModel.swift  (Phase 3–4)
├── Services/
│   ├── CameraService.swift            (Phase 3)
│   ├── FaceDetectionService.swift     (Phase 4)
│   ├── APIService.swift               (Phase 5)
│   └── ImageProcessingService.swift   (Phase 5)
├── Models/
│   ├── Student.swift                  ✅
│   └── EnrollmentPayload.swift        ✅
├── Theme/
│   └── KUTheme.swift                  ✅ KU brand palette + typography
└── Resources/
    └── Assets.xcassets                ✅ KU colors, KU logo (official), app icon
```

---

## 6. Technology Stack (M1 MacBook buildable)

| Layer | Technology | Notes |
|---|---|---|
| IDE | Xcode (26.6 installed) | Native Apple Silicon |
| Language | Swift 5.9 / Swift 6 (installed 6.3.3) | `async/await` for camera + networking |
| UI | SwiftUI | `UIViewControllerRepresentable` for camera preview |
| Camera | AVFoundation | No third-party dependency |
| Face detection | Vision framework | On-device Neural Engine, quality gating |
| Networking | URLSession + `async/await` | `multipart/form-data` |
| Dependency mgmt | Swift Package Manager | Preferred over CocoaPods |
| Version control | Git | Repo initialized in `ku-onboarding/` |

**Why Vision over a 3rd-party SDK:** recognition happens on the backend; the client only needs face detection + quality gating — Vision does this natively, on-device, no SDK licensing.

---

## 7. Backend & Face Recognition Pipeline (separate from iOS app)

1. Receive 5–10 frames + Banner ID (`POST /api/v1/enroll`).
2. Generate face embeddings — `face_recognition` (prototype), InsightFace/ArcFace (production), or cloud APIs (AWS Rekognition, Azure Face, GCP Vision).
3. Store embeddings + Banner ID in PostgreSQL + `pgvector` (or Weaviate/Pinecone at scale).
4. Attendance kiosk later captures a face → embedding → nearest-neighbor search.

| Backend component | Option |
|---|---|
| API server | Python FastAPI or Node.js Express/NestJS |
| Embedding | InsightFace (self-hosted) or AWS Rekognition (managed) |
| Database | PostgreSQL + pgvector |
| File storage | S3-compatible, encrypted at rest |
| Hosting | AWS/Azure per KU cloud agreement / residency policy |

A reference backend spec is tracked in [docs/BACKEND.md](docs/BACKEND.md).

---

## 8. Privacy & Compliance

- Explicit consent screen before camera activates (what data is used for, retention period).
- **UAE Federal PDPL** compliance — biometric data is sensitive personal data; consult KU IT/legal.
- Do not persist raw face images on-device after upload.
- HTTPS/TLS everywhere; consider certificate pinning.
- Backend: encrypt embeddings/images at rest, role-based access, audit logging.
- Provide student/admin data-deletion request path.

Details in [docs/PRIVACY.md](docs/PRIVACY.md).

---

## 9. Khalifa University Branding (implemented)

- Official KU logo downloaded from `ku.ac.ae` (`KU_Logo-1-1.zip`) and shipped as:
  - `KULogo` (blue/black official mark on transparent — light surfaces)
  - `KULogoWhite` (white knock-out — brand-blue surfaces, splash, icon)
- Verified official KU Blue: **`#1C4F9D`** (sampled from the official logo; aligns with KU brand guidelines Pantone family).
- Digital app palette derived for accessibility (blue + white theme):
  - KU Blue `#1C4F9D` — primary / CTA
  - KU Blue Deep `#123B8A` — gradient + focus rings
  - KU Blue Soft `#EBF6FC` — light surfaces
  - KU White `#FFFFFF` — surfaces / text on brand blue
  - KU Text `#1D1D23` — body text on light
- App icon generated: KU-blue 1024×1024 tile with white official wordmark.
- Localization planned for English + Arabic (`Localizable.strings`, RTL layout).

Full brand usage notes in [docs/BRANDING.md](docs/BRANDING.md).

> ⚠️ **Replace placeholder logo verification with the university-approved export** before public release. Contact KU Communications & Business Development.

---

## 10. Build Roadmap & Status

| Phase | Deliverable | Status |
|---|---|---|
| 1 | Xcode scaffold, SwiftUI navigation, KU theme (colors/fonts/logo/icon) | ✅ Done |
| 2 | Banner ID input + validation (+ unit tests) | ✅ Done |
| 3 | Camera integration (`AVCaptureSession`) + preview in SwiftUI | ⏳ Next |
| 4 | Vision face detection + auto-capture (5–10 quality-gated frames) | Pending |
| 5 | Networking: multipart upload to backend | Pending |
| 6 | Processing/Success screens + error handling | Pending |
| 7 | Backend enrollment endpoint + embedding + storage | Parallel track |
| 8 | End-to-end test on physical device, consent/privacy, polish | Pending |

Estimated total (solo dev, both client + minimal backend): **2–3 weeks**.

---

## 11. Getting Started (first 3 commands)

```bash
open ku-onboarding.xcodeproj          # open in Xcode
xcodebuild -project ku-onboarding.xcodeproj -scheme ku-onboarding \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# camera flow requires a physical iPhone
```

Full manual: [docs/MANUAL.md](docs/MANUAL.md)
All documents: [docs/INDEX.md](docs/INDEX.md)