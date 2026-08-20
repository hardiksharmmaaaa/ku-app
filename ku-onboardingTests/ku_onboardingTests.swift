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
        let ids = ["B00123456", "B00000001", "B99999999"]
        for id in ids {
            #expect(StudentInfoViewModel.isBannerIDValid(id))
        }
    }

    @Test func invalidBannerIDs() {
        let ids = ["b00123456", "B1234567", "B001234567", "C00123456", "00123456", "B01A23456", "", "B0012 3456"]
        for id in ids {
            #expect(!StudentInfoViewModel.isBannerIDValid(id))
        }
    }

    @MainActor
    @Test func viewModelNormalizesInput() {
        let vm = StudentInfoViewModel()
        vm.bannerID = "b001"
        #expect(vm.bannerID == "B001")
    }
}