//
//  Student.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//

import Foundation

struct Student: Codable, Identifiable, Hashable {
    var id: String { bannerID }

    let bannerID: String
    var fullName: String?
    var college: String?
}