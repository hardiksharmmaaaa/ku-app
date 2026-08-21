//
//  ku_onboardingTests.swift
//  ku-onboardingTests
//
//  Created by Hardik Sharma on 20/08/26.
//

import Testing
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