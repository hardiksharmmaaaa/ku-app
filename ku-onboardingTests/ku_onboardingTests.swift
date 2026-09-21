//
//  ku_onboardingTests.swift
//  ku-onboardingTests
//
//  Created by Hardik Sharma on 20/08/26.
//

import Testing
import Foundation
import CoreMedia
import CoreVideo
import ImageIO
@testable import ku_onboarding

struct BannerIDTests {

    @Test func validBannerIDs() {
        let ids = ["100012345", "100000001", "100099999"]
        for id in ids {
            #expect(StudentInfoViewModel.isBannerIDValid(id))
        }
    }

    @Test func invalidBannerIDs() {
        let ids = ["10012345", "1000123456", "100112345", "00123456", "100A12345", "", "1000 12345"]
        for id in ids {
            #expect(!StudentInfoViewModel.isBannerIDValid(id))
        }
    }

    @MainActor
    @Test func viewModelNormalizesInput() {
        let vm = StudentInfoViewModel()
        vm.bannerID = "10001"
        #expect(vm.bannerID == "10001")
    }
}

struct EnrollmentPayloadTests {

    @Test func encodesSnakeCaseContract() throws {
        let payload = EnrollmentPayload(
            bannerID: "100012345",
            deviceModel: "iPhone17,1",
            frames: [
                EnrollmentFrame(index: 0, width: 1080, height: 1920, jpegDataBase64: "QUJD")
            ]
        )

        let data = try JSONEncoder().encode(payload)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["banner_id"] as? String == "100012345")
        #expect(json["device_model"] as? String == "iPhone17,1")
        let frames = try #require(json["frames"] as? [[String: Any]])
        #expect(frames[0]["jpeg_base64"] as? String == "QUJD")
        #expect(frames[0]["index"] as? Int == 0)
        #expect(json["bannerID"] == nil)
    }

    @Test func decodesServerResponse() throws {
        let json = #"{"status":"ok","enrollment_id":"ABC-123"}"#
        let response = try JSONDecoder().decode(EnrollmentResponse.self, from: Data(json.utf8))
        #expect(response.status == "ok")
        #expect(response.enrollmentID == "ABC-123")
    }

    @MainActor
    @Test func deviceModelIsNonEmpty() {
        #expect(!FaceEnrollmentViewModel.deviceModel.isEmpty)
    }
}

struct ImageProcessingServiceTests {

    @Test func jpegKeepsPortraitCameraBufferUpright() throws {
        let sampleBuffer = try makeSampleBuffer(width: 40, height: 80)
        let jpeg = try #require(ImageProcessingService().jpegData(from: sampleBuffer))
        let source = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )

        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 40)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 80)
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
    }

    private func makeSampleBuffer(width: Int, height: Int) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ] as CFDictionary
        let pixelStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &pixelBuffer
        )
        #expect(pixelStatus == kCVReturnSuccess)
        let unwrappedPixelBuffer = try #require(pixelBuffer)

        CVPixelBufferLockBaseAddress(unwrappedPixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(unwrappedPixelBuffer) {
            memset(baseAddress, 0x7F, CVPixelBufferGetDataSize(unwrappedPixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, [])

        var formatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: unwrappedPixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        #expect(formatStatus == noErr)

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: unwrappedPixelBuffer,
            formatDescription: try #require(formatDescription),
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        #expect(sampleStatus == noErr)

        return try #require(sampleBuffer)
    }
}
