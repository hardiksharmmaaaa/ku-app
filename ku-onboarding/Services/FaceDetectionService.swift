//
 //  FaceDetectionService.swift
 //  ku-onboarding
 //
 //  Created by Hardik Sharma on 20/08/26.
 //
 //  Vision framework wrapper: quality-gates each camera frame before it is
 //  accepted into the enrollment set (single face, centered, well-sized, good quality).
 //  Uses VNImageRequestHandler with explicit orientation so both front & rear cameras work.
 
 import Foundation
 import Vision
 import CoreImage
 import CoreMedia
 
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
 
         let orientation = orientationFromSampleBuffer(sampleBuffer)
         let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
 
         let rectRequest = VNDetectFaceRectanglesRequest()
         let qualityRequest = VNDetectFaceCaptureQualityRequest()
 
         do {
             try handler.perform([rectRequest, qualityRequest])
 
             guard let observations = rectRequest.results, !observations.isEmpty else {
                 return FaceAssessment(passes: false, faceCount: 0, faceRect: nil, reason: "Look directly at the camera — no face found.")
             }
 
             guard observations.count == 1 else {
                 return FaceAssessment(passes: false, faceCount: observations.count, faceRect: observations.first?.boundingBox, reason: "Only one person should be in the frame.")
             }
 
             let rect = observations[0].boundingBox
 
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
 
             let quality = qualityRequest.results?.first?.captureQuality?.score
             if let quality, quality < 0.25 {
                 return FaceAssessment(passes: false, faceCount: 1, faceRect: rect, reason: "Face is not clear — improve lighting")
             }
 
             return FaceAssessment(passes: true, faceCount: 1, faceRect: rect, reason: nil)
         } catch {
             return FaceAssessment(passes: false, faceCount: 0, faceRect: nil, reason: "vision-error: \(error.localizedDescription)")
         }
     }
 
/// Extracts CGImagePropertyOrientation from the sample buffer's attachment.
 /// Falls back to .right (front camera typical) if not present.
 private func orientationFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
     let key = kCMSampleBufferAttachmentKey_CameraOrientation as CFString
     guard let attachment = CMGetAttachment(sampleBuffer, key: key, attachmentModeOut: nil) as? NSNumber else {
         return .right
     }
     return CGImagePropertyOrientation(rawValue: attachment.uint32Value) ?? .right
 }