//
//  ConfirmationView.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 21/08/26.
//
//  Step 2 — shows the entered Banner ID back to the student so a typo
//  never reaches the biometric database.
//

import SwiftUI

struct ConfirmationView: View {
    let bannerID: String
    var onConfirm: () -> Void = {}
    var onEdit: () -> Void = {}

    var body: some View {
        ZStack {
            KUTheme.blueSoft
                .ignoresSafeArea()

            VStack(spacing: 28) {
                StepIndicator(step: 2)

                Spacer()

                VStack(spacing: 18) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 56))
                        .foregroundStyle(KUTheme.blue)

                    Text("Is this you?")
                        .font(KUTheme.titleFont)
                        .foregroundStyle(KUTheme.text)

                    Text("Confirm this is your Banner ID before face enrollment.")
                        .font(KUTheme.bodyFont)
                        .foregroundStyle(KUTheme.text.opacity(0.6))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 6) {
                        Text("Banner ID")
                            .font(KUTheme.captionFont)
                            .foregroundStyle(KUTheme.text.opacity(0.55))
                        Text(bannerID)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(KUTheme.text)
                            .kerning(2)
                    }
                    .padding(.vertical, 22)
                    .padding(.horizontal, 44)
                    .background(KUTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: KUTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: KUTheme.cornerRadius)
                            .stroke(KUTheme.blue.opacity(0.35), lineWidth: 2)
                    )
                    .accessibilityElement(children: .combine)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        onConfirm()
                    } label: {
                        Text("Yes — It's Correct")
                            .font(KUTheme.bodyFont.bold())
                            .foregroundStyle(KUTheme.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: KUTheme.buttonHeight)
                            .background(KUTheme.blue)
                            .clipShape(RoundedRectangle(cornerRadius: KUTheme.cornerRadius))
                    }
                    .accessibilityHint("Continues to the privacy consent screen")

                    Button {
                        Haptics.tap()
                        onEdit()
                    } label: {
                        Text("Edit ID")
                            .font(KUTheme.bodyFont.bold())
                            .foregroundStyle(KUTheme.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: KUTheme.buttonHeight)
                            .background(KUTheme.white)
                            .clipShape(RoundedRectangle(cornerRadius: KUTheme.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: KUTheme.cornerRadius)
                                    .stroke(KUTheme.blue.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                }
            }
            .padding(24)
        }
    }
}

#Preview {
    ConfirmationView(bannerID: "100012345")
}
