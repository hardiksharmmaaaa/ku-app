//
//  FaceDetectionService.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Vision framework wrapper (modern Swift API, iOS 18+): quality-gates each
//  camera frame before it is accepted into the enrollment set
//  (single face, centered, well-sized, good quality).

import Foundation
import Vision
import CoreImage

struct FaceAssessment {
    let passes: Bool
    let faceCount: Int
    let faceRect: CGRect?
    let reason: String?
}

final class FaceDetectionService {

    /// Face must occupy between 8% and 40% of the frame (normalized area).
    private let minFaceCoverage: CGFloat = 0.08
    private let maxFaceCoverage: CGFloat = 0.40

    /// Horizontal center tolerance (normalized).
    private let centerTolerance: CGFloat = 0.15

    nonisolated func assess(_ sampleBuffer: CMSampleBuffer) async -> FaceAssessment {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return FaceAssessment(passes: false, faceCount: 0, faceRect: nil, reason: "no-frame")
        }

        let rectRequest = DetectFaceRectanglesRequest()
        let qualityRequest = DetectFaceCaptureQualityRequest()

        do {
            async let rectResult = rectRequest.perform(on: pixelBuffer)
            async let qualityResult = qualityRequest.perform(on: pixelBuffer)
            let (observations, qualityFaces) = try await (rectResult, qualityResult)

            guard !observations.isEmpty else {
                return FaceAssessment(passes: false, faceCount: 0, faceRect: nil, reason: "Look directly at the camera — no face found.")
            }

            guard observations.count == 1 else {
                return FaceAssessment(passes: false, faceCount: observations.count, faceRect: observations.first?.boundingBox.cgRect, reason: "Only one person should be in the frame.")
            }

            let rect = observations[0].boundingBox.cgRect

            let area = rect.width * rect.height
            guard area >= minFaceCoverage, area <= maxFaceCoverage else {
                let tooFar = area < minFaceCoverage
                return FaceAssessment(
                    passes: false,
                    faceCount: 1,
                    faceRect: rect,
                    reason: tooFar ? "Move closer to the camera" : "Move slightly further from the camera"
                )
            }

            let midX = rect.midX
            guard abs(midX - 0.5) <= centerTolerance else {
                return FaceAssessment(
                    passes: false,
                    faceCount: 1,
                    faceRect: rect,
                    reason: "Center your face in the oval"
                )
            }

            let quality = qualityFaces.first?.captureQuality?.score
            if let quality, quality < 0.25 {
                return FaceAssessment(passes: false, faceCount: 1, faceRect: rect, reason: "Face is not clear — improve lighting")
            }

            return FaceAssessment(passes: true, faceCount: 1, faceRect: rect, reason: nil)
        } catch {
            return FaceAssessment(passes: false, faceCount: 0, faceRect: nil, reason: "vision-error: \(error.localizedDescription)")
        }
    }
}