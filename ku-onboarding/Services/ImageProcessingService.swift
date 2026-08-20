//
//  ImageProcessingService.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Compresses accepted camera frames to JPEG (~80%) for upload.

import Foundation
import CoreImage
import CoreVideo
import CoreMedia
import UIKit

final class ImageProcessingService {

    func jpegData(from sampleBuffer: CMSampleBuffer, quality: CGFloat = 0.8) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let orient = imageOrientation(from: sampleBuffer)
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orient)
        return image.jpegData(compressionQuality: quality)
    }

    /// The front camera delivers buffers in landscape; reflect to portrait-up
    /// so the JPEGs store correctly for the backend embedding pipeline.
    private func imageOrientation(from sampleBuffer: CMSampleBuffer) -> UIImage.Orientation {
        .right
    }
}