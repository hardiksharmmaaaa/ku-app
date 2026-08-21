//
//  EnrollmentPayload.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Wire contract for the `enroll` Edge Function (docs/SUPABASE.md §5).
//  Keys are snake_case to match the server contract exactly.
//

import Foundation

/// JSON body sent to `POST /functions/v1/enroll`.
struct EnrollmentPayload: Encodable, Equatable {
    let bannerID: String
    let deviceModel: String?
    let frames: [EnrollmentFrame]

    enum CodingKeys: String, CodingKey {
        case bannerID = "banner_id"
        case deviceModel = "device_model"
        case frames
    }
}

/// One JPEG frame, base64-encoded.
struct EnrollmentFrame: Encodable, Equatable {
    let index: Int
    let width: Int?
    let height: Int?
    let jpegDataBase64: String

    enum CodingKeys: String, CodingKey {
        case index
        case width
        case height
        case jpegDataBase64 = "jpeg_base64"
    }
}

/// Success response from the `enroll` Edge Function.
struct EnrollmentResponse: Decodable, Equatable {
    let status: String
    let enrollmentID: String

    enum CodingKeys: String, CodingKey {
        case status
        case enrollmentID = "enrollment_id"
    }
}
