//
//  StudentInfoView.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Screen 1 — the student enters only their Banner ID.

import SwiftUI

struct StudentInfoView: View {
    @StateObject private var viewModel = StudentInfoViewModel()

    /// Called with the validated Banner ID when the user taps Continue.
    var onContinue: (String) -> Void = { _ in }

    var body: some View {
        ZStack {
            KUTheme.blueSoft
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // KU monogram + wordmark
                HStack(spacing: 12) {
                    Circle()
                        .fill(KUTheme.blue)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text("KU")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(KUTheme.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Khalifa University")
                            .font(KUTheme.titleFont)
                            .foregroundStyle(KUTheme.text)
                        Text("Smart Attendance Enrollment")
                            .font(KUTheme.captionFont)
                            .foregroundStyle(KUTheme.text.opacity(0.6))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Banner ID")
                        .font(KUTheme.bodyFont)
                        .foregroundStyle(KUTheme.text)

                    TextField("e.g. B00123456", text: $viewModel.bannerID)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .padding()
                        .background(KUTheme.white)
                        .clipShape(RoundedRectangle(cornerRadius: KUTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: KUTheme.cornerRadius)
                                .stroke(
                                    viewModel.isValid ? KUTheme.blue : KUTheme.text.opacity(0.2),
                                    lineWidth: 2
                                )
                        )

                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .font(KUTheme.captionFont)
                            .foregroundStyle(Color.red)
                    }
                }

                Spacer()

                Button {
                    onContinue(viewModel.bannerID)
                } label: {
                    Text("Continue")
                        .font(KUTheme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(KUTheme.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: KUTheme.buttonHeight)
                        .background(KUTheme.blue)
                        .clipShape(RoundedRectangle(cornerRadius: KUTheme.cornerRadius))
                }
                .disabled(!viewModel.isValid)
                .opacity(viewModel.isValid ? 1 : 0.4)

                Text("Your Banner ID is printed on your student card and available in MyKU.")
                    .font(KUTheme.captionFont)
                    .foregroundStyle(KUTheme.text.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}

#Preview {
    StudentInfoView()
}