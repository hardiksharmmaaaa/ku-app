export const BANNER_ID_RE = /^1000\d{5}$/;
export const MAX_FRAMES = 10;

/** Build an object key rooted at the student's validated KU/Banner ID. */
export function buildEnrollmentFramePath(
  bannerId: string,
  frameIndex: number,
): string {
  if (!BANNER_ID_RE.test(bannerId)) throw new Error("invalid_banner_id");
  if (
    !Number.isInteger(frameIndex) ||
    frameIndex < 0 ||
    frameIndex >= MAX_FRAMES
  ) {
    throw new Error("invalid_frame_index");
  }

  return `${bannerId}/frame_${String(frameIndex).padStart(2, "0")}.jpg`;
}
