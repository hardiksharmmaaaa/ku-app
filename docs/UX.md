# UX / Wireframes — KU Smart Attendance Onboarding App

Doc: **D-009** · Last updated: 20 August 2026

## Screen map

```
Splash ──▶ Student Info ──▶ [Consent] ──▶ Face Enrollment ──▶ Processing ──▶ Success
                                            (based on camera permission)          │
                                                                                   ▼
                                                                              Redo capture ↺
```

## Wireframe notes

### Splash (done)
- Full-bleed KU Blue gradient (`KUTheme.heroGradient`).
- White KU logo centered; "Smart Attendance · Face Enrollment" subtitle.
- Auto-advance after ~1.5 s.

### Student Info (done)
- Soft blue background; KU monogram + "Khalifa University" header.
- Single large Banner ID field, uppercase-normalized.
- Error caption below field when invalid format.
- Disabled "Continue" button until valid.

### Face Enrollment (planned)
- Camera preview full-screen; face oval guide centered.
- Pose prompt pill: "Look straight" / "Turn slightly left" / "Turn slightly right".
- Progress ring + "3 of 8" counter; quality indicator (bad lighting / too close / too far).
- Auto-stop at target frames or 6 s timeout.

### Processing
- Spinner + uploading frames + Banner ID; progress fraction.

### Success
- KU Blue celebratory view; "You're enrolled!"; "Redo capture" secondary button.

## Interaction rules
- Continue disabled⇆enabled based on `isValid`.
- Do not block back-navigation on Student Info.
- Capture screen: on quality failure, prompt text explains the required fix.