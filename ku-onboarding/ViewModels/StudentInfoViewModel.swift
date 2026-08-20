//
//  StudentInfoViewModel.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Validates the Banner ID before enabling "Continue".

import Foundation
import Combine

final class StudentInfoViewModel: ObservableObject {

    @Published var bannerID = "" {
        didSet {
            let normalized = bannerID.uppercased().filter { $0.isLetter || $0.isNumber }
            if normalized != bannerID {
                bannerID = normalized
            }
        }
    }

    @Published private(set) var errorMessage = ""

    /// Khalifa University Banner ID format:
    /// a single leading letter (B) followed by 8 digits, e.g. B00123456.
    private static let pattern = #"^B\d{8}$"#

    static func isBannerIDValid(_ id: String) -> Bool {
        id.range(of: pattern, options: .regularExpression) != nil
    }

    var isValid: Bool {
        Self.isBannerIDValid(bannerID)
    }

    func validate() {
        if bannerID.isEmpty {
            errorMessage = ""
        } else if isValid {
            errorMessage = ""
        } else {
            errorMessage = "Banner ID must start with 'B' followed by 8 digits (e.g., B00123456)."
        }
    }
}
