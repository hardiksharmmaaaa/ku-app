# Supabase Backend Plan — KU Smart Attendance Onboarding App

Doc: **D-011** · Last updated: 21 August 2026
Status: 🕓 Planned → in implementation

This document is the single source of truth for the app's persistence layer: what is stored, where, how it is secured, and how the stored data feeds the future facial-recognition system.

---

## 1. Purpose & Scope

The onboarding app currently captures quality-gated face frames but stores nothing — frames are placeholder stubs in memory and are discarded when the flow ends.

**Goal:** persist every enrollment so a separate attendance/recognition system can match faces later.

| In scope | Out of scope |
|---|---|
| Storing enrollment frames + Banner ID | Taking attendance |
| Metadata (device, timestamps, frame count) | Face recognition / matching |
| Embedding pipeline hand-off (status tracking) | Kiosk UI |
| Duplicate-enrollment protection | Student-facing data dashboard |

**Decisions made:**

| Decision | Choice | Rationale |
|---|---|---|
| Backend platform | **Supabase** (Postgres + Storage + Edge Functions) | Managed Postgres w/ pgvector, storage, serverless functions in one free tier |
| Embedding generation | **External Python worker** (InsightFace/ArcFace) | Edge Functions can't run heavy ML models reliably; matches D-005 stack |
| iOS integration | **supabase-swift SDK** via SPM | Official, typed API for functions/storage/postgrest |
| Key strategy | Anon key in app + RLS lockdown; service-role key only inside Edge Function secrets | Biometric data must never be client-writable |

---

## 2. Architecture

```
iPhone (onboarding app)
   │  ① POST /functions/v1/enroll
   │     { banner_id, frames: [{index, jpeg_base64}] }
   ▼
Supabase Edge Function: enroll            (service-role key, server-side only)
   │  ② validate banner_id (^1000\d{5}$), reject duplicates (409)
   │  ③ decode JPEGs → upload to Storage bucket "enrollment-frames"
   │  ④ insert students / enrollments / enrollment_frames rows
   │  ⑤ leave enrollments.status = 'pending'
   ▼
Python embedding worker (separate host; Mac initially)
   │  polls enrollments WHERE status = 'pending'
   │  downloads frames → InsightFace buffalo_l → 512-d embeddings
   │  writes face_embeddings → sets status = 'embedded' (or 'failed')
   ▼
Postgres + pgvector
   └── consumed later by attendance kiosk:
       live face → embedding → cosine nearest-neighbor search
```

Key property: **the iOS app never talks to Postgres or Storage directly.** All writes go through the Edge Function, which holds the service-role key. The anon key shipped in the app is useless against RLS-locked tables.

---

## 3. Database Schema

Run in Supabase Dashboard → SQL Editor:

```sql
-- Vector support for embeddings
create extension if not exists vector;

-- One row per student identity
create table public.students (
  banner_id  text primary key check (banner_id ~ '^1000\d{5}$'),
  created_at timestamptz not null default now()
);

-- One row per enrollment attempt that reached upload
create table public.enrollments (
  id           uuid primary key default gen_random_uuid(),
  banner_id    text not null references public.students on delete cascade,
  status       text not null default 'pending'
               check (status in ('pending', 'embedded', 'failed')),
  frame_count  int  not null,
  device_model text,
  created_at   timestamptz not null default now()
);

-- Only one active (non-failed) enrollment per student
create unique index one_active_enrollment
  on public.enrollments (banner_id)
  where status <> 'failed';

-- Individual frame records pointing at Storage objects
create table public.enrollment_frames (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments on delete cascade,
  frame_index   int  not null,
  storage_path  text not null,          -- '{banner_id}/frame_03.jpg'
  width         int,
  height        int,
  unique (enrollment_id, frame_index)
);

-- Computed by the Python worker; consumed by recognition system
create table public.face_embeddings (
  id            uuid primary key default gen_random_uuid(),
  banner_id     text not null references public.students on delete cascade,
  enrollment_id uuid references public.enrollments on delete cascade,
  source_frame  uuid references public.enrollment_frames on delete set null,
  embedding     vector(512) not null,   -- InsightFace buffalo_l dimension
  model         text not null default 'buffalo_l',
  created_at    timestamptz not null default now()
);

-- Similarity search index for the future recognition system
create index face_embeddings_search
  on public.face_embeddings
  using hnsw (embedding vector_cosine_ops);

-- Lock everything down: clients get nothing, service role bypasses RLS
alter table public.students          enable row level security;
alter table public.enrollments       enable row level security;
alter table public.enrollment_frames enable row level security;
alter table public.face_embeddings   enable row level security;
```

Notes:

- `one_active_enrollment` enforces duplicate protection at the DB level — the Edge Function maps the unique-violation to HTTP `409`.
- `on delete cascade` everywhere means deleting a student removes their entire biometric footprint (PDPL right-to-deletion path).
- HNSW index added now so the recognition system needs no migration later.

## 4. Storage

| Setting | Value |
|---|---|
| Bucket | `enrollment-frames` |
| Visibility | **Private** (signed URLs only) |
| Path layout | `{banner_id}/frame_{NN}.jpg` (the student's KU/Banner ID) |
| Content type | `image/jpeg` |
| Retention | Frames kept until worker marks `embedded`; optional purge job deletes objects after embedding (config flag in worker) |

No storage policies grant client access — uploads happen exclusively from the Edge Function using the service-role key.

---

## 5. Edge Function: `enroll`

Deployed with `supabase functions deploy enroll`. Contract:

### Request

`POST /functions/v1/enroll` · header `Authorization: Bearer <anon-key>`

```json
{
  "banner_id": "100012345",
  "device_model": "iPhone15,2",
  "frames": [
    { "index": 0, "jpeg_base64": "…", "width": 1080, "height": 1920 }
  ]
}
```

Constraints enforced server-side: banner format regex, frame count 5–10, each frame ≤ ~500 KB decoded, total body ≤ 8 MB.

### Responses

| Code | Body | Meaning |
|---|---|---|
| `200` | `{ "status": "ok", "enrollment_id": "uuid" }` | Stored, queued for embedding |
| `400` | `{ "error": "…" }` | Bad banner ID / no frames / oversized |
| `409` | `{ "error": "already_enrolled" }` | Active enrollment exists → app offers redo/reset |
| `500` | `{ "error": "…" }` | Server fault → app retries |

### Secrets (set once via `supabase secrets set`)

None required beyond the built-in `SUPABASE_SERVICE_ROLE_KEY` — the function uses it for DB inserts and Storage uploads.

---

## 6. iOS Integration

| File | Change |
|---|---|
| `project.pbxproj` | Add `supabase-swift` SPM dependency |
| `Config/Secrets.xcconfig` *(new, gitignored)* | `SUPABASE_URL` + `SUPABASE_ANON_KEY`; template `Secrets.xcconfig.example` committed |
| `Services/SupabaseConfig.swift` *(new)* | Reads xcconfig values; fails fast if missing |
| `Services/APIService.swift` *(new)* | `func enroll(_ payload: EnrollmentPayload) async throws -> EnrollmentResponse` via Edge Function client; typed errors `.duplicate`, `.invalidID`, `.network`, `.server` |
| `Models/EnrollmentPayload.swift` | Add `EnrollmentResponse`; align field names (`banner_id`, snake_case) with function contract |
| `ViewModels/FaceEnrollmentViewModel.swift` | **Replace placeholder capture**: store real `jpegData(from:)` per accepted frame; run upload during `.processing`; map errors to retry UI; success only after server confirms |

Behavior changes:

1. Accepted frames are real JPEGs (~80% quality) held in memory until upload completes, then discarded.
2. `.processing` now performs the network call; the 2.5 s animation masks latency.
3. New failure state surfaces retry; `409` routes to the existing "Redo capture" path.
4. No raw frames persisted on-device after upload (PDPL).

---

## 7. Python Embedding Worker (`worker/`, separate track)

Minimal loop, runnable on a Mac:

```python
# pseudo-flow
while True:
    jobs = db.table("enrollments").select("*").eq("status", "pending").limit(5).execute()
    for job in jobs:
        frames = download_from_storage(job.id)          # signed URLs / service client
        for f in frames:
            emb = insightface.get_embedding(f)          # buffalo_l, 512-d
            insert into face_embeddings(...)
        update enrollments.status = "embedded"          # or "failed" on error
```

- Dependencies: `supabase-py`, `insightface`, `onnxruntime`
- Idempotent: re-running a job overwrites embeddings for its enrollment
- Hosting: local Mac initially; any container host later (Fly.io, a KU VM, etc.)

---

## 8. Security & Privacy Checklist

- [x] Service-role key only in Edge Function environment — never in app bundle or repo
- [x] RLS enabled on all tables, zero anon policies → leaked anon key reads/writes nothing
- [x] Private storage bucket, no public URLs
- [x] Payload size limits enforced server-side (DoS protection)
- [x] Cascade deletion gives one-command erasure of a student's biometric data
- [ ] Consent screen before camera/upload (Phase 8, PDPL review — see D-006)
- [ ] Decide frame retention policy after embedding (purge job flag)

---

## 9. Implementation Order

| Step | Deliverable | Status |
|---|---|---|
| 1 | This plan document | ✅ Done |
| 2 | SQL schema applied to Supabase project + bucket created | ⏳ Next |
| 3 | `enroll` Edge Function deployed + curl smoke test | Pending |
| 4 | iOS: SPM package, xcconfig, `SupabaseConfig`, `APIService` | Pending |
| 5 | iOS: real frame capture wired into `FaceEnrollmentViewModel` + error/retry states | Pending |
| 6 | End-to-end test on physical iPhone against Supabase project | Pending |
| 7 | Python worker skeleton + first embedded enrollment | Pending |
| 8 | Docs updated (`API.md`, `BACKEND.md`, `ARCHITECTURE.md`, `MANUAL.md`) | Pending |

Estimated effort: steps 2–6 ≈ one focused day; step 7 ≈ half day.

---

## 10. Local Development & Smoke Tests

```bash
# Deploy the function
supabase functions deploy enroll --project-ref <ref>

# Smoke test (valid ID)
curl -X POST "https://<ref>.supabase.co/functions/v1/enroll" \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"banner_id":"100012345","device_model":"sim","frames":[{"index":0,"jpeg_base64":"<...>","width":10,"height":10}]}'

# Expect 200 {status: ok}; repeat → 409 already_enrolled
```

Unit tests on the iOS side mock `APIService` (protocol) so the capture FSM is testable without network.

---

Related: [BACKEND.md](BACKEND.md) (D-005) · [API.md](API.md) (D-008) · [PRIVACY.md](PRIVACY.md) (D-006) · [ARCHITECTURE.md](ARCHITECTURE.md) (D-004)
