//
//  EnrollmentPayload.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//

import Foundation

/// Multipart payload sent to `POST /api/v1/enroll`.
struct EnrollmentPayload: Codable {
    let bannerID: String
    let studentEmail: String?
    let frames: [EnrollmentFrame]
}

struct EnrollmentFrame: Codable {
    let index: Int
    let width: Int
    let height: Int
    let jpegDataBase64: String
}