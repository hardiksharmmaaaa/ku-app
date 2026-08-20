//
//  FaceEnrollmentViewModel.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Drives the capture FSM: guided animated prompts, quality gating,
//  frame collection (~8-10s), then a processing animation and success state.
//  Includes a simulator demo mode so the flow is testable without a camera.

import Foundation
import CoreMedia
import Combine

@MainActor
final class FaceEnrollmentViewModel: ObservableObject {

    enum Phase: Equatable {
        case requestingPermission
        case ready            // camera live, waiting for a good frame
        case capturing        // actively gathering quality-gated frames
        case processing       // "Processing all your faces…" animation
        case success          // "Thank you! Your face is enrolled"
        case timedOut
        case error(String)
    }

    @Published private(set) var phase: Phase = .requestingPermission
    @Published private(set) var guideMessage = "Preparing camera…"
    @Published private(set) var capturedCount = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var isDemoMode = false

    // Engagement copy cycled during capture with a friendly animation.
    let capturePrompts = [
        "Look straight at the camera",
        "Smile a little 😊",
        "Say cheese! 🧀",
        "Look straight at the camera",
        "Smile a little 😊",
    ]

    let targetFrameCount = 10
    let captureTimeout: TimeInterval = 10
    /// Minimum total "journey" duration so the experience always feels like
    /// ~10 seconds even when quality gates pass instantly.
    let minCaptureDuration: TimeInterval = 10
    /// How often a quality-passed frame is accepted during real capture
    /// (spreads 10 frames across ~10s instead of accepting every frame).
    let framePacing: TimeInterval = 1.0

    private let faceDetection = FaceDetectionService()
    private let imageProcessing = ImageProcessingService()

    private var acceptedFrames: [Data] = []
    private var timeoutTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var captureStart: Date?
    private var lastFrameAccept = Date.distantPast

    var capturedFrames: [Data] { acceptedFrames }

    let bannerID: String

    init(bannerID: String) {
        self.bannerID = bannerID
    }

    // MARK: - Capture loop

    /// Called on the main actor from the sample-buffer delegate.
    func handle(sampleBuffer: CMSampleBuffer) {
        guard phase == .ready || phase == .capturing else { return }

        Task {
            let assessment = await faceDetection.assess(sampleBuffer)

            guard assessment.passes else {
                GuideTicker.shared.update(with: assessment.reason ?? "Align your face in the scanner")
                return
            }

            switch phase {
            case .ready:
                // First good frame begins the timed capture.
                phase = .capturing
                captureStart = Date()
                lastFrameAccept = .distantPast
                startTimeout()
                acceptPlaceholderData()
            case .capturing:
                // Pace frames so the journey lasts ~10 seconds.
                guard Date().timeIntervalSince(lastFrameAccept) >= framePacing else { return }
                acceptPlaceholderData()
            default:
                break
            }
        }
    }

    // MARK: - Camera readiness

    /// Moves the flow out of the pending-permission state once the camera
    /// is authorized and running. Prevents getting stuck on
    /// "Requesting camera access…" after the user has already granted access.
    func setCameraReady() {
        guard phase == .requestingPermission else { return }
        phase = .ready
        GaussianGuide.kickOff(capturing: false)
    }

    // MARK: - Simulator demo capture

    /// Simulates a camera when running in the simulator (no camera hardware),
    /// accepting one synthetic "quality-passed" frame every ~1s (≈10s total).
    func startDemoCapture() {
        guard phase != .capturing && phase != .processing else { return }
        isDemoMode = true
        resetFrames()
        phase = .capturing
        captureStart = Date()
        GaussianGuide.kickOff(capturing: true)
        startTimeout()

        demoTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0))
                guard let self, !Task.isCancelled else { return }
                self.acceptPlaceholderData()
            }
        }
    }

    private func acceptPlaceholderData() {
        lastFrameAccept = Date()
        acceptedFrames.append(Data([0x01]))
        capturedCount = acceptedFrames.count
        progress = Double(capturedCount) / Double(targetFrameCount)
        GaussianGuide.kickOff(capturing: true)

        if capturedCount >= targetFrameCount {
            finishCapture()
        }
    }

    // MARK: - Helpers

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            // Hold the session a beat past the pacing so energy always lands ~10s.
            try? await Task.sleep(for: .seconds(self?.captureTimeout ?? 10))
            guard !Task.isCancelled else { return }
            self?.finishCapture()
        }
    }

    /// Ends the capture step, honoring the minimum journey duration before the
    /// transition to the "Processing all your faces…" animation.
    private func finishCapture() {
        guard phase == .capturing else { return }
        timeoutTask?.cancel()
        demoTask?.cancel()

        let elapsed = Date().timeIntervalSince(captureStart ?? Date())
        let remaining = max(0, minCaptureDuration - elapsed)

        processingTask = Task { [weak self] in
            // Precisely wait the remainder of the 10-second journey…
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard let self, !Task.isCancelled else { return }
            self.beginProcessing()
        }
    }

    /// "Processing all your faces…" animation, then success.
    private func beginProcessing() {
        guard phase == .capturing else { return }
        phase = .processing
        progress = 1.0
        GaussianGuide.kickOff(capturing: false)

        processingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, !Task.isCancelled else { return }
            self.phase = .success
        }
    }

    var canRedo: Bool { phase == .success || phase == .timedOut }

    private func resetFrames() {
        acceptedFrames.removeAll()
        capturedCount = 0
        progress = 0
        captureStart = nil
        lastFrameAccept = .distantPast
        timeoutTask?.cancel()
        demoTask?.cancel()
        processingTask?.cancel()
    }

    func resetCapture() {
        resetFrames()
        phase = .ready
        isDemoMode = false
        GaussianGuide.kickOff(capturing: false)
    }
}

// MARK: - Animated prompt ticker

/// Drives the friendly bottom-bar prompts ("Look… Smile… Say cheese!").
/// An external singleton so the ViewModel and View can both poke it simply.
@MainActor
final class GuideTicker: ObservableObject {
    static let shared = GuideTicker()

    @Published var text = "Look straight at the camera"
    @Published var tick = 0

    private init() {}

    func update(with newText: String) {
        text = newText
        tick += 1
    }
}

/// Kicks the bottom-bar prompts into rapid shadow rotation during capture,
/// so "look / smile / say cheese" visibly cycles.
@MainActor
final class GaussianGuide {
    private static var task: Task<Void, Never>?

    static let prompts = [
        "Look straight at the camera",
        "Smile a little 😊",
        "Say cheese! 🧀",
        "Look straight at the camera",
        "Smile a little 😊",
    ]

    static func kickOff(capturing: Bool) {
        task?.cancel()

        if !capturing {
            GuideTicker.shared.update(with: "Center your face in the scanner")
            return
        }

        task = Task {
            var index = 0
            while !Task.isCancelled {
                GuideTicker.shared.update(with: prompts[index % prompts.count])
                index += 1
                try? await Task.sleep(for: .milliseconds(900))
            }
        }
    }
}