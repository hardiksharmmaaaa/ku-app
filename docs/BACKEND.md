# Backend & Face Recognition Pipeline (Reference)

Doc: **D-005** · Last updated: 20 August 2026
**Out of scope for the iOS app** — documented here so the client contract and pipeline shape are clear.

## 1. Enrollment flow

```
iOS app ──multipart POST /api/v1/enroll──▶ API server
    { bannerID, frames[] }                     │
                                              ├─ Generate embeddings
                                              ├─ Store embeddings + bannerID
                                              └─ Respond { status, id }
```

## 2. Embedding generation options


| Option                       | Use case                                                                |
| ---------------------------- | ----------------------------------------------------------------------- |
| `face_recognition` (dlib)    | Fast prototyping on a laptop                                            |
| InsightFace / ArcFace        | Production-grade, self-hosted                                           |
| AWS Rekognition / Azure Face | Fastest integration, managed, recurring cost + residency considerations |




## 3. Storage

- **PostgreSQL + pgvector** (recommended open-source) — embeddings + Banner ID + similarity search.
- Or vector DBs (Weaviate/Pinecone) when attendance-match scale grows.
- Raw frames optional; if retained, S3-compatible storage **encrypted at rest**.



## 4. Suggested stack


| Layer        | Option                                                     |
| ------------ | ---------------------------------------------------------- |
| AP,I server  | Python (FastAPI) or Node (Express/NestJS)                  |
| Embeddings   | InsightFace (self-hosted) or managed API                   |
| DB           | PostgreSQL + pgvector                                      |
| File storage | S3-compatible, encrypted                                   |
| Hosting      | AWS/Azure (check KU institutional cloud / residency rules) |




## 5. Attendance matching (later, separate system)

Kiosk/classroom camera → live face → embedding → nearest-neighbor search over enrolled embeddings → record attendance.

---

Full API contract: `docs/API.md` (D-008).