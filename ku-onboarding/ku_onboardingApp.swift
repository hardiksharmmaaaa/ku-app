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
/// then routes to the Banner ID entry screen.
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                NavigationStack {
                    StudentInfoView()
                        .navigationBarHidden(true)
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