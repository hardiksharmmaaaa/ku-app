# API Contract — KU Smart Attendance Onboarding App

Doc: **D-008** · Last updated: 20 August 2026 (draft pending backend)

## `POST /api/v1/enroll`

Uploads Banner ID + face frames for embedding generation.

### Request — `multipart/form-data`

| Field | Type | Notes |
|---|---|---|
| `banner_id` | string | e.g. `B00123456` |
| `frames[]` | files (JPEG) | 5–10 images, ~80% quality |

### Response — success `200`

```json
{
  "status": "ok",
  "enrollment_id": "uuid",
  "embeddings_generated": 1
}
```

### Response — errors

| Code | Meaning |
|---|---|
| `400` | Invalid banner ID / no frames |
| `401` | Auth failure / expired token |
| `409` | Banner ID already enrolled (offer reset) |
| `5xx` | Server error → client retries |

### Client notes

- Multipart built in `APIService`; frames compressed with `ImageProcessingService`.
- On failure, show retry; on `409`, offer "Redo capture" or reset enrollment.
- Timeout awareness: reasonable per-frame upload budget; show progress.

## Later endpoint (attendance system, separate app)

`POST /api/v1/recognize` — live face → `{ student, confidence }`.