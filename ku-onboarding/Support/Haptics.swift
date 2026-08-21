//
//  Haptics.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 21/08/26.
//
//  Centralized haptic feedback so the whole app feels consistent.
//  No-ops on devices without a Taptic Engine (e.g. Simulator).
//

import UIKit

enum Haptics {
    /// One quality-gated frame accepted during capture.
    static func frameAccepted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Generic button tap / step advance.
    static func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Enrollment completed successfully.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Soft attention cue (e.g. already enrolled).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Capture failed or upload errored.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
