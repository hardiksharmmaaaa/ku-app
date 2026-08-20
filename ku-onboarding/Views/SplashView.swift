//
//  SplashView.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            KUTheme.heroGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("KULogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)

                Text("Smart Attendance")
                    .font(KUTheme.titleFont)
                    .foregroundStyle(KUTheme.white)

                Text("Face Enrollment")
                    .font(KUTheme.bodyFont)
                    .foregroundStyle(KUTheme.white.opacity(0.85))

                ProgressView()
                    .tint(KUTheme.white)
                    .padding(.top, 12)
            }
        }
    }
}

#Preview {
    SplashView()
}