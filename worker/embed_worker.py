# KU Smart Attendance — embedding worker (docs/SUPABASE.md §7)
#
# Polls enrollments with status='pending', downloads their frames from
# Storage, computes InsightFace embeddings, writes face_embeddings rows,
# and marks the enrollment 'embedded' (or 'failed').
#
# Setup:
#   python -m venv .venv && source .venv/bin/activate
#   pip install supabase insightface onnxruntime numpy
#   export SUPABASE_URL="https://<ref>.supabase.co"
#   export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"   # never commit
#   python embed_worker.py
#
# The service-role key bypasses RLS — this worker is trusted infrastructure.

import io
import os
import sys
import time

import numpy as np
from supabase import create_client


def load_dotenv(path: str = os.path.join(os.path.dirname(__file__), ".env")) -> None:
    """Minimal .env loader — fills os.environ without clobbering existing values."""
    if not os.path.exists(path):
        return
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())


load_dotenv()

URL = os.environ["SUPABASE_URL"]
KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
BUCKET = "enrollment-frames"
POLL_SECONDS = 10
BATCH = 5

client = create_client(URL, KEY)

# Model loads once (~330 MB download on first run).
face_app = None


def get_model():
    global face_app
    if face_app is None:
        from insightface.app import FaceAnalysis

        face_app = FaceAnalysis(name="buffalo_l")
        face_app.prepare(ctx_id=0, det_size=(640, 640))
    return face_app


def embed(jpeg_bytes: bytes) -> np.ndarray | None:
    import cv2

    img = cv2.imdecode(np.frombuffer(jpeg_bytes, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        return None
    faces = get_model().get(img)
    if not faces:
        return None
    # Use the largest detected face's normalized embedding.
    best = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
    return best.normed_embedding


def process(enrollment: dict) -> None:
    enrollment_id = enrollment["id"]
    banner_id = enrollment["banner_id"]

    frames = (
        client.table("enrollment_frames")
        .select("id, frame_index, storage_path")
        .eq("enrollment_id", enrollment_id)
        .order("frame_index")
        .execute()
        .data
    )

    written = 0
    for frame in frames:
        obj = client.storage.from(BUCKET).download(frame["storage_path"])
        vector = embed(obj)
        if vector is None:
            print(f"  no face in frame {frame['frame_index']}, skipping")
            continue
        client.table("face_embeddings").upsert(
            {
                "banner_id": banner_id,
                "enrollment_id": enrollment_id,
                "source_frame": frame["id"],
                "embedding": vector.tolist(),
                "model": "buffalo_l",
            },
            on_conflict="enrollment_id,source_frame",
        ).execute()
        written += 1

    status = "embedded" if written > 0 else "failed"
    client.table("enrollments").update({"status": status}).eq(
        "id", enrollment_id
    ).execute()
    print(f"enrollment {enrollment_id}: {written} embeddings -> {status}")


def main() -> None:
    print(f"worker polling {URL} every {POLL_SECONDS}s")
    while True:
        try:
            pending = (
                client.table("enrollments")
                .select("*")
                .eq("status", "pending")
                .limit(BATCH)
                .execute()
                .data
            )
            for enrollment in pending:
                print(f"processing enrollment {enrollment['id']}")
                try:
                    process(enrollment)
                except Exception as exc:  # keep the loop alive
                    print(f"  FAILED: {exc}", file=sys.stderr)
                    client.table("enrollments").update(
                        {"status": "failed"}
                    ).eq("id", enrollment["id"]).execute()
        except Exception as exc:
            print(f"poll error: {exc}", file=sys.stderr)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
