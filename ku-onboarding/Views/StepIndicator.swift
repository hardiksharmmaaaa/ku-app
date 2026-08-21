//
//  StepIndicator.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 21/08/26.
//
//  "Step X of 4" progress dots shown on the pre-camera screens:
//  1 ID entry · 2 Confirm · 3 Consent · 4 Face scan.
//

import SwiftUI

struct StepIndicator: View {
    let step: Int

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { index in
                    if index > 1 {
                        Capsule()
                            .fill(index <= step ? KUTheme.blue : KUTheme.text.opacity(0.15))
                            .frame(width: 16, height: 2)
                    }
                    Circle()
                        .fill(index <= step ? KUTheme.blue : KUTheme.text.opacity(0.15))
                        .frame(width: index == step ? 12 : 8, height: index == step ? 12 : 8)
                        .overlay {
                            if index < step {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(KUTheme.white)
                            }
                        }
                }
            }
            Text("Step \(step) of \(totalSteps)")
                .font(KUTheme.captionFont)
                .foregroundStyle(KUTheme.text.opacity(0.55))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(totalSteps)")
    }
}

#Preview {
    VStack(spacing: 32) {
        StepIndicator(step: 1)
        StepIndicator(step: 2)
        StepIndicator(step: 3)
        StepIndicator(step: 4)
    }
}
