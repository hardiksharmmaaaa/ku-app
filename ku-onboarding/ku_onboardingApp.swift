//
//  ku_onboardingApp.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//

import SwiftUI

@main
struct ku_onboardingApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
    }
}

/// Top-level coordinator: shows the KU-branded splash while the app boots,
/// then routes through ID entry → confirmation → consent → face enrollment.
struct RootView: View {
    @State private var showSplash = true
    @State private var path: [Route] = []

    enum Route: Hashable {
        case confirmID(bannerID: String)
        case consent(bannerID: String)
        case faceEnrollment(bannerID: String)
    }

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                NavigationStack(path: $path) {
                    StudentInfoView { bannerID in
                        path.append(.confirmID(bannerID: bannerID))
                    }
                    .navigationBarHidden(true)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .confirmID(let bannerID):
                            ConfirmationView(
                                bannerID: bannerID,
                                onConfirm: { path.append(.consent(bannerID: bannerID)) },
                                onEdit: { path.removeLast() }
                            )
                            .navigationBarHidden(true)
                        case .consent(let bannerID):
                            ConsentView(
                                bannerID: bannerID,
                                onAgree: { path.append(.faceEnrollment(bannerID: bannerID)) },
                                onCancel: { path.removeLast() }
                            )
                            .navigationBarHidden(true)
                        case .faceEnrollment(let bannerID):
                            FaceEnrollmentView(
                                bannerID: bannerID,
                                onFinish: { path = [] }
                            )
                        }
                    }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }
}