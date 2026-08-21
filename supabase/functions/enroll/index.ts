// KU Smart Attendance — `enroll` Edge Function (docs/SUPABASE.md §5)
//
// Deploy:
//   supabase functions deploy enroll --project-ref <ref>
//
// Contract:
//   POST /functions/v1/enroll
//   Authorization: Bearer <anon-key>
//   { "banner_id": "100012345", "device_model": "iPhone17,1",
//     "frames": [{ "index": 0, "jpeg_base64": "...", "width": 1080, "height": 1920 }] }
//
//   200 { "status": "ok", "enrollment_id": "<uuid>" }
//   400 { "error": "invalid_banner_id" | "invalid_frame_count" | "frame_too_large" | ... }
//   409 { "error": "already_enrolled" }
//   500 { "error": "..." }
//
// Uses the built-in SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars.
// The service-role key bypasses RLS; it never leaves this function.

import { createClient } from "jsr:@supabase/supabase-js@2";

const BANNER_ID_RE = /^1000\d{5}$/;
const MIN_FRAMES = 5;
const MAX_FRAMES = 10;
const MAX_FRAME_BYTES = 512 * 1024;
const FRAME_BUCKET = "enrollment-frames";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function fail(error: string, status: number): Response {
  return json({ error }, status);
}

interface IncomingFrame {
  index: number;
  jpeg_base64: string;
  width?: number;
  height?: number;
}

Deno.serve(async (req: Request) => {
  let body: { banner_id?: string; device_model?: string; frames?: IncomingFrame[] };
  try {
    body = await req.json();
  } catch {
    return fail("invalid_json", 400);
  }

  const bannerId = body.banner_id ?? "";
  if (!BANNER_ID_RE.test(bannerId)) return fail("invalid_banner_id", 400);

  const frames = Array.isArray(body.frames) ? body.frames : [];
  if (frames.length < MIN_FRAMES || frames.length > MAX_FRAMES) {
    return fail("invalid_frame_count", 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Upsert the student identity.
  const { error: studentErr } = await admin
    .from("students")
    .upsert({ banner_id: bannerId });
  if (studentErr) return fail(studentErr.message, 500);

  // Create the enrollment. The partial unique index makes a second active
  // enrollment for the same student fail here.
  const { data: enrollment, error: enrollErr } = await admin
    .from("enrollments")
    .insert({
      banner_id: bannerId,
      status: "pending",
      frame_count: frames.length,
      device_model: body.device_model ?? null,
    })
    .select("id")
    .single();

  if (enrollErr) {
    if (enrollErr.code === "23505") return fail("already_enrolled", 409);
    return fail(enrollErr.message, 500);
  }

  const enrollmentId = enrollment.id as string;

  // Store each frame; roll everything back on any failure so a broken
  // upload never leaves a half-written enrollment blocking retries.
  try {
    for (const frame of frames) {
      if (!Number.isInteger(frame.index) || frame.index < 0 || frame.index >= MAX_FRAMES) {
        throw new Error("invalid_frame_index");
      }
      const bytes = Uint8Array.from(atob(frame.jpeg_base64), (c) => c.charCodeAt(0));
      if (bytes.byteLength === 0 || bytes.byteLength > MAX_FRAME_BYTES) {
        throw new Error("frame_too_large");
      }

      const path =
        `${enrollmentId}/frame_${String(frame.index).padStart(2, "0")}.jpg`;
      const { error: uploadErr } = await admin.storage
        .from(FRAME_BUCKET)
        .upload(path, bytes, {
          contentType: "image/jpeg",
          upsert: true,
        });
      if (uploadErr) throw new Error(uploadErr.message);

      const { error: rowErr } = await admin.from("enrollment_frames").insert({
        enrollment_id: enrollmentId,
        frame_index: frame.index,
        storage_path: path,
        width: frame.width ?? null,
        height: frame.height ?? null,
      });
      if (rowErr) throw new Error(rowErr.message);
    }
  } catch (cause) {
    const message = cause instanceof Error ? cause.message : "upload_failed";
    const paths = frames.map(
      (_, i) => `${enrollmentId}/frame_${String(i).padStart(2, "0")}.jpg`,
    );
    await admin.storage.from(FRAME_BUCKET).remove(paths);
    await admin.from("enrollments").delete().eq("id", enrollmentId);
    return fail(message, message === "frame_too_large" ? 400 : 500);
  }

  return json({ status: "ok", enrollment_id: enrollmentId });
});
