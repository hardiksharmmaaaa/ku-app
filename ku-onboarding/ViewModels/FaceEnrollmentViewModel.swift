//
//  FaceEnrollmentViewModel.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Drives the capture FSM: guided animated prompts, quality gating,
//  frame collection (~8-10s), then a real upload to the Supabase
//  `enroll` Edge Function during the processing animation, then success.
//  Includes a simulator demo mode so the flow is testable without a camera.
//

import Foundation
import CoreMedia
import UIKit
import Combine

@MainActor
final class FaceEnrollmentViewModel: ObservableObject {

    enum Phase: Equatable {
        case requestingPermission
        case ready            // camera live, waiting for a good frame
        case capturing        // actively gathering quality-gated frames
        case processing       // uploading frames to the backend
        case success          // "Thank you! Your face is enrolled"
        case alreadyEnrolled  // server returned 409 — friendly duplicate screen
        case timedOut
        case error(String)
    }

    @Published private(set) var phase: Phase = .requestingPermission
    @Published private(set) var guideMessage = String(localized: "Preparing camera…")
    @Published private(set) var capturedCount = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var isDemoMode = false

    // Engagement copy cycled during capture with a friendly animation.
    let capturePrompts = [
        String(localized: "Look straight at the camera"),
        String(localized: "Smile a little 😊"),
        String(localized: "Say cheese! 🧀"),
        String(localized: "Look straight at the camera"),
        String(localized: "Smile a little 😊"),
    ]

    let targetFrameCount = 10
    /// Maximum idle gap between accepted frames. Reset on every accepted
    /// frame — if the face disappears mid-capture, the session times out
    /// instead of proceeding with partial data.
    let captureTimeout: TimeInterval = 10
    /// Minimum total "journey" duration so the experience always feels like
    /// ~10 seconds even when quality gates pass instantly.
    let minCaptureDuration: TimeInterval = 10
    /// How often a quality-passed frame is accepted during real capture
    /// (spreads 10 frames across ~10s instead of accepting every frame).
    let framePacing: TimeInterval = 1.0

    private let faceDetection = FaceDetectionService()
    private let imageProcessing = ImageProcessingService()
    private let apiService: EnrollingService

    private var acceptedFrames: [Data] = []
    private var timeoutTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var captureStart: Date?
    private var lastFrameAccept = Date.distantPast

    var capturedFrames: [Data] { acceptedFrames }

    /// True when an upload failed but usable frames are still in memory,
    /// so the error screen can offer a retry instead of recapture.
    var canRetryUpload: Bool {
        guard case .error = phase else { return false }
        return !acceptedFrames.isEmpty
    }

    let bannerID: String

    init(bannerID: String, apiService: EnrollingService = APIService()) {
        self.bannerID = bannerID
        self.apiService = apiService
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
                acceptFrame(from: sampleBuffer)
            case .capturing:
                // Pace frames so the journey lasts ~10 seconds.
                guard Date().timeIntervalSince(lastFrameAccept) >= framePacing else { return }
                acceptFrame(from: sampleBuffer)
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
    /// accepting one synthetic quality-passed frame every ~1s (≈10s total).
    /// Synthetic frames are tiny valid JPEGs so the full upload pipeline
    /// can be exercised end-to-end without a device.
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
                self.acceptDemoFrame()
            }
        }
    }

    private func acceptFrame(from sampleBuffer: CMSampleBuffer) {
        // Convert synchronously — the buffer is reused by the camera queue.
        guard let jpeg = imageProcessing.jpegData(from: sampleBuffer) else { return }
        accept(jpeg)
    }

    private func acceptDemoFrame() {
        accept(Self.demoJPEG())
    }

    private func accept(_ jpeg: Data) {
        lastFrameAccept = Date()
        acceptedFrames.append(jpeg)
        capturedCount = acceptedFrames.count
        progress = Double(capturedCount) / Double(targetFrameCount)
        Haptics.frameAccepted()
        GaussianGuide.kickOff(capturing: true)

        if capturedCount >= targetFrameCount {
            finishCapture()
        } else {
            // Keep the session alive while the face keeps delivering frames.
            startTimeout()
        }
    }

    /// A small valid JPEG used by demo mode so uploads carry real image bytes.
    private static func demoJPEG() -> Data {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(white: 0.6, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data([0x01])
    }

    // MARK: - Helpers

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            // Hold the session a beat past the pacing so energy always lands ~10s.
            try? await Task.sleep(for: .seconds(self?.captureTimeout ?? 10))
            guard !Task.isCancelled else { return }
            self?.handleIdleTimeout()
        }
    }

    /// Fires only when the face stopped delivering usable frames before the
    /// target was reached — never proceed to processing with partial data.
    private func handleIdleTimeout() {
        guard phase == .capturing else { return }
        phase = .timedOut
        Haptics.error()
        GaussianGuide.kickOff(capturing: false)
    }

    /// Ends the capture step once every target frame is stored, honoring the
    /// minimum journey duration before the transition to the
    /// "Processing all your faces…" animation.
    private func finishCapture() {
        guard phase == .capturing, acceptedFrames.count >= targetFrameCount else { return }
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

    /// Uploads the captured frames while the "Processing all your faces…"
    /// animation plays. Success only after the server confirms storage.
    private func beginProcessing() {
        guard phase == .capturing || phase == .error("") else { return }
        phase = .processing
        progress = 1.0
        GaussianGuide.kickOff(capturing: false)

        processingTask = Task { [weak self] in
            // Keep the animation on screen at least 2.5 s even on fast uploads.
            async let minimumAnimation: Void = {
                try? await Task.sleep(for: .seconds(2.5))
            }()
            async let upload: Void = self?.performUpload() ?? ()
            _ = await (minimumAnimation, upload)
        }
    }

    private func performUpload() async {
        let payload = EnrollmentPayload(
            bannerID: bannerID,
            deviceModel: Self.deviceModel,
            frames: acceptedFrames.enumerated().map { index, jpeg in
                EnrollmentFrame(index: index, width: nil, height: nil, jpegDataBase64: jpeg.base64EncodedString())
            }
        )

        do {
            _ = try await apiService.enroll(payload)
            acceptedFrames.removeAll()   // no raw biometric data lingers on-device
            Haptics.success()
            phase = .success
        } catch EnrollmentError.duplicate {
            acceptedFrames.removeAll()
            Haptics.warning()
            phase = .alreadyEnrolled
        } catch let error as EnrollmentError {
            Haptics.error()
            phase = .error(error.errorDescription ?? "Enrollment failed.")
        } catch {
            Haptics.error()
            phase = .error(EnrollmentError.network(error.localizedDescription).errorDescription ?? "Enrollment failed.")
        }
    }

    /// Re-attempts the upload after a failure, keeping the already-captured
    /// frames in memory. Offered via the Retry button on the error screen.
    func retryUpload() {
        guard canRetryUpload else { return }
        beginProcessing()
    }

    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            let data = Data(buffer.prefix(while: { $0 != 0 }))
            return String(decoding: data, as: UTF8.self)
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
        // isDemoMode intentionally survives resets — it reflects the
        // device's lack of a camera, not the outcome of one attempt.
        GaussianGuide.kickOff(capturing: false)
    }
}

// MARK: - Animated prompt ticker

/// Drives the friendly bottom-bar prompts ("Look… Smile… Say cheese!").
/// An external singleton so the ViewModel and View can both poke it simply.
@MainActor
final class GuideTicker: ObservableObject {
    static let shared = GuideTicker()

    @Published var text = String(localized: "Look straight at the camera")
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
        String(localized: "Look straight at the camera 👀"),
        String(localized: "Smile like your final's over 😁"),
        String(localized: "Say cheese! 🧀"),
        String(localized: "Big smile, no passport photo face! 📸"),
    ]

    static func kickOff(capturing: Bool) {
        task?.cancel()

        if !capturing {
            GuideTicker.shared.update(with: String(localized: "Center your face in the scanner"))
            return
        }

        task = Task {
            var index = 0
            while !Task.isCancelled {
                GuideTicker.shared.update(with: prompts[index % prompts.count])
                index += 1
                try? await Task.sleep(for: .milliseconds(1700))
            }
        }
    }
}