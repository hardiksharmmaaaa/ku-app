import assert from "node:assert/strict";
import test from "node:test";

import { buildEnrollmentFramePath } from "./storage_path.ts";

test("uses each student's KU/Banner ID as the enrollment frame folder", () => {
  const cases = [
    ["100012345", 3, "100012345/frame_03.jpg"],
    ["100098765", 9, "100098765/frame_09.jpg"],
  ] as const;

  for (const [bannerId, frameIndex, expectedPath] of cases) {
    assert.equal(
      buildEnrollmentFramePath(bannerId, frameIndex),
      expectedPath,
    );
  }
});

test("rejects values that could create unexpected Storage paths", () => {
  assert.throws(
    () => buildEnrollmentFramePath("8f9c552d-614e-44c1-bf48-5687188290e3", 0),
    /invalid_banner_id/,
  );
  assert.throws(
    () => buildEnrollmentFramePath("100012345", 10),
    /invalid_frame_index/,
  );
});
