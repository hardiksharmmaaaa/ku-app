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
                StepIndicator(step: 1)

                Spacer()

                // Official KU logo + tagline, centered
                VStack(spacing: 10) {
                    Image("KULogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 64)
                        .accessibilityHidden(true)

                    Text("Smart Attendance Enrollment")
                        .font(KUTheme.captionFont)
                        .foregroundStyle(KUTheme.text.opacity(0.6))
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Banner ID")
                        .font(KUTheme.bodyFont)
                        .foregroundStyle(KUTheme.text)

                    TextField("e.g. 100012345", text: $viewModel.bannerID)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)
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
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil
                                    )
                                }
                                .font(KUTheme.bodyFont.bold())
                            }
                        }

                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .font(KUTheme.captionFont)
                            .foregroundStyle(Color.red)
                    }
                }

                Spacer()

                Button {
                    Haptics.tap()
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