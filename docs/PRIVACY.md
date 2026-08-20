# Privacy & Compliance — KU Smart Attendance Onboarding App

Doc: **D-006** · Last updated: 20 August 2026

Biometric data tied to real identity is **sensitive personal data**. Build compliance from day one.

## Requirements

- [ ] **Explicit consent screen** before camera activates — state what data is collected (face frames), why (attendance enrollment), how long it's retained.
- [ ] **UAE Federal Data Protection Law (PDPL)** compliance — biometrics are sensitive; coordinate with KU IT/Legal before production.
- [ ] **No on-device persistence** of raw face images after upload (clear memory/disk).
- [ ] **HTTPS/TLS** for all uploads; evaluate certificate pinning.
- [ ] **Backend controls**: encrypt embeddings/images at rest, role-based access, audit logging.
- [ ] **Deletion path**: student/admin request to delete enrolled biometric data.

## Data minimization

- Collect the minimum: Banner ID + frames sufficient for embedding.
- Store embeddings (not raw images) wherever possible.
- Frames used transiently, discarded after successful enrollment.

## Consent copy (draft)

> "Khalifa University records your face patterns to create your attendance profile. Captured images are used only for enrollment and are not stored on this device. Data is handled per KU's privacy policy and UAE data-protection law. You can request deletion at any time."

## App-side implementation notes

- `NSCameraUsageDescription` already set in `Info.plist`.
- Add a consent screen before `FaceEnrollmentView` (Phase 8).
- Do not write frames to `UserDefaults`/disk; keep in memory until upload completes.