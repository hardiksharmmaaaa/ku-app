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
            let normalized = bannerID.filter { $0.isNumber }
            if normalized != bannerID {
                bannerID = normalized
            }
        }
    }

    @Published private(set) var errorMessage = ""

    /// Khalifa University Banner ID format:
    /// starts with 1000 followed by 5 digits, e.g. 100069933 (9 digits total).
    private static let pattern = #"^1000\d{5}$"#

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
            errorMessage = "Banner ID must start with '1000' followed by 5 digits (e.g., 100xxxxx)."
        }
    }
}
