//
//  ConsentView.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 21/08/26.
//
//  Step 3 — explicit informed consent before any biometric capture.
//  Required under UAE Federal PDPL: states what is collected, why,
//  where it goes, and how it is retained. See docs/PRIVACY.md.
//

import SwiftUI

struct ConsentView: View {
    let bannerID: String
    var onAgree: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        ZStack {
            KUTheme.blueSoft
                .ignoresSafeArea()

            VStack(spacing: 24) {
                StepIndicator(step: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(spacing: 6) {
                            Text("Before We Enroll Your Face")
                                .font(KUTheme.titleFont)
                                .foregroundStyle(KUTheme.text)
                            Text("Enrolling Banner ID \(bannerID)")
                                .font(KUTheme.captionFont.bold())
                                .foregroundStyle(KUTheme.blue)
                        }
                        .frame(maxWidth: .infinity)

                        consentRow(
                            icon: "camera.viewfinder",
                            text: "We capture about 10 short video frames of your face using the front camera."
                        )
                        consentRow(
                            icon: "server.rack",
                            text: "Frames upload securely to Khalifa University servers, where they become your face template for Smart Attendance."
                        )
                        consentRow(
                            icon: "lock.shield",
                            text: "Your face template is used only for attendance verification — never shared or used for anything else."
                        )
                        consentRow(
                            icon: "trash",
                            text: "Raw frames are deleted after processing and nothing is stored on your phone."
                        )
                        consentRow(
                            icon: "doc.text",
                            text: "Handled in line with UAE PDPL and KU IT policies."
                        )

                        Text("You can withdraw consent at any time by contacting KU IT services.")
                            .font(KUTheme.captionFont)
                            .foregroundStyle(KUTheme.text.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 4)
                }

                VStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        onAgree()
                    } label: {
                        Text("I Agree — Start Face Scan")
                            .font(KUTheme.bodyFont.bold())
                            .foregroundStyle(KUTheme.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: KUTheme.buttonHeight)
                            .background(KUTheme.blue)
                            .clipShape(RoundedRectangle(cornerRadius: KUTheme.cornerRadius))
                    }
                    .accessibilityHint("Grants consent and opens the camera")

                    Button {
                        Haptics.tap()
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(KUTheme.bodyFont.bold())
                            .foregroundStyle(KUTheme.text.opacity(0.7))
                    }
                }
            }
            .padding(24)
        }
    }

    private func consentRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(KUTheme.blue)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(KUTheme.bodyFont)
                .foregroundStyle(KUTheme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ConsentView(bannerID: "100012345")
}
