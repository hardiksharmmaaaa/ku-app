//
//  FaceEnrollmentView.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Screen 2 — live front-camera preview with an animated scan line,
//  friendly cycling prompts ("Look… Smile… Say cheese!"), a progress ring,
//  then a "Processing all your faces…" animation and a success state.

import SwiftUI
import AVFoundation
import UIKit

struct FaceEnrollmentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()
    @StateObject private var viewModel: FaceEnrollmentViewModel
    @StateObject private var ticker = GuideTicker.shared
    @State private var promptScale: CGFloat = 0.8

    /// Called when the flow reaches a terminal state (enrolled / already
    /// enrolled) so the coordinator can send the student back to the start.
    var onFinish: () -> Void = {}

    init(bannerID: String, onFinish: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: FaceEnrollmentViewModel(bannerID: bannerID))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.phase {
            case .capturing, .ready, .requestingPermission:
                cameraStage
            case .processing:
                processingStage
            case .success:
                successStage
            case .alreadyEnrolled:
                alreadyEnrolledStage
            case .timedOut:
                timedOutStage
            case .error(let msg):
                errorStage(msg)
            }
        }
        .task {
            await camera.requestAccess()
            camera.onSampleBuffer = { [weak viewModel] buffer in
                viewModel?.handle(sampleBuffer: buffer)
            }
            camera.start()
            if camera.isAuthorized, !camera.hasNoCameraDevice {
                viewModel.setCameraReady()
            }
        }
        .onDisappear {
            camera.onSampleBuffer = nil
            camera.stop()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Camera stage

    private var cameraStage: some View {
        ZStack {
            if camera.isAuthorized, !camera.hasNoCameraDevice {
                CameraPreviewView(service: camera)
                    .ignoresSafeArea()
            } else {
                KUTheme.heroGradient.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                permissionOverlay
                Spacer()
                captureFooter
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KUTheme.white)
                    .padding(10)
                    .background(KUTheme.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel("Close camera")

            Spacer()

            Label(viewModel.bannerID, systemImage: "person.badge.key")
                .font(KUTheme.captionFont.bold())
                .foregroundStyle(KUTheme.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(KUTheme.white.opacity(0.2), in: Capsule())

            Spacer()

            // Front / back camera switch
            if camera.isAuthorized, !camera.hasNoCameraDevice {
                Button {
                    camera.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KUTheme.white)
                        .padding(10)
                        .background(KUTheme.white.opacity(0.2), in: Circle())
                }
                .accessibilityLabel("Switch camera")
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Permission / unavailable overlay

    @ViewBuilder
    private var permissionOverlay: some View {
        if camera.isAuthorized, !camera.hasNoCameraDevice {
            // Transparent scan area — only the animated line is visible.
            ScannerScanLine()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "face.smiling")
                    .font(.system(size: 54))
                    .foregroundStyle(KUTheme.white)
                    .symbolEffect(.bounce, value: ticker.tick)
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: "camera.fill.badge.ellipsis")
                    .font(.system(size: 46))
                    .foregroundStyle(KUTheme.white)

                Text(permissionTitle)
                    .font(KUTheme.titleFont)
                    .foregroundStyle(KUTheme.white)
                    .multilineTextAlignment(.center)

                Text(permissionMessage)
                    .font(KUTheme.bodyFont)
                    .foregroundStyle(KUTheme.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if camera.hasNoCameraDevice {
                    Button {
                        viewModel.startDemoCapture()
                    } label: {
                        Label("Simulate Capture (Demo)", systemImage: "play.rectangle.fill")
                            .font(KUTheme.bodyFont.bold())
                            .foregroundStyle(KUTheme.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(KUTheme.blue, in: Capsule())
                    }
                } else if !camera.isAuthorized {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(KUTheme.bodyFont.bold())
                            .foregroundStyle(KUTheme.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(KUTheme.blue, in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var permissionTitle: String {
        camera.hasNoCameraDevice
            ? String(localized: "Simulator Detected")
            : (camera.isAuthorized
                ? String(localized: "Camera Ready")
                : String(localized: "Camera Access Required"))
    }

    private var permissionMessage: String {
        if camera.hasNoCameraDevice {
            return "Face enrollment needs a real front camera. For testing here, run a simulated capture that exercises the full flow."
        }
        if !camera.isAuthorized {
            return "Enable camera access in Settings so we can enroll your face for attendance."
        }
        return camera.unavailableReason ?? "Enable camera access in Settings to continue."
    }

    // MARK: - Capture footer (animated prompts + progress ring)

    private var captureFooter: some View {
        VStack(spacing: 18) {
            if viewModel.phase == .requestingPermission {
                HStack(spacing: 14) {
                    ProgressView()
                        .tint(KUTheme.white)
                    Text("Requesting camera access…")
                        .font(KUTheme.bodyFont)
                        .foregroundStyle(KUTheme.white)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(KUTheme.blueDeep.opacity(0.6), in: Capsule())
            } else {
                // Animated prompt bubble that cycles look / smile / say cheese!
                Text(ticker.text)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(KUTheme.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(KUTheme.blue.opacity(0.6), in: Capsule())
                    .contentTransition(.opacity)
                    .scaleEffect(promptScale)
                    .onChange(of: ticker.tick) { _, _ in
                        promptScale = 0.85
                        withAnimation(.spring(duration: 0.5, bounce: 0.5)) {
                            promptScale = 1.0
                        }
                    }

                if viewModel.phase == .capturing || viewModel.isDemoMode {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(KUTheme.white.opacity(0.3), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: viewModel.progress)
                                .stroke(KUTheme.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(viewModel.capturedCount) / \(viewModel.targetFrameCount)")
                                .font(KUTheme.bodyFont.bold())
                                .foregroundStyle(KUTheme.white)
                        }
                        .frame(width: 76, height: 76)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Capture progress")
                        .accessibilityValue("\(viewModel.capturedCount) of \(viewModel.targetFrameCount) frames")

                        Text(statusText)
                            .font(KUTheme.bodyFont)
                            .foregroundStyle(KUTheme.white)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(KUTheme.blueDeep.opacity(0.6), in: Capsule())
                }
            }
        }
    }

    private var statusText: String {
        viewModel.isDemoMode
            ? "Simulating capture — \(viewModel.capturedCount) of \(viewModel.targetFrameCount)"
            : String(localized: "Capturing your face")
    }

    // MARK: - Processing stage

    private var processingStage: some View {
        ZStack {
            KUTheme.heroGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                ScannerScanLine()
                    .frame(width: 180, height: 180)

                Text("Processing all your faces…")
                    .font(KUTheme.titleFont)
                    .foregroundStyle(KUTheme.white)
                    .multilineTextAlignment(.center)

                ProgressView()
                    .tint(KUTheme.white)
                    .scaleEffect(1.3)
            }
        }
    }

    // MARK: - Success stage

    private var successStage: some View {
        ZStack {
            KUTheme.heroGradient.ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(KUTheme.white)
                    .symbolEffect(.bounce, value: 1)
                    .accessibilityHidden(true)

                Text("Thank You!!")
                    .font(KUTheme.displayFont)
                    .foregroundStyle(KUTheme.white)

                Text("Your face is enrolled")
                    .font(KUTheme.titleFont)
                    .foregroundStyle(KUTheme.white.opacity(0.95))

                Text(viewModel.bannerID)
                    .font(KUTheme.bodyFont.bold())
                    .monospacedDigit()
                    .foregroundStyle(KUTheme.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(KUTheme.white.opacity(0.2), in: Capsule())

                VStack(alignment: .leading, spacing: 12) {
                    Text("What happens next?")
                        .font(KUTheme.bodyFont.bold())
                        .foregroundStyle(KUTheme.white)

                    nextStepRow(icon: "hourglass", text: "Your face template is processed securely on university servers.")
                    nextStepRow(icon: "door.right.hand.open", text: "You'll be recognized automatically at attendance kiosks.")
                    nextStepRow(icon: "iphone.slash", text: "Nothing is stored on this device.")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KUTheme.blueDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: KUTheme.cornerRadius))

                Button("Done") {
                    onFinish()
                }
                .buttonStyle(KUFilledButtonStyle())
                .padding(.top, 6)
            }
            .padding(24)
        }
    }

    private func nextStepRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KUTheme.white.opacity(0.9))
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(KUTheme.captionFont)
                .foregroundStyle(KUTheme.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Already enrolled stage

    private var alreadyEnrolledStage: some View {
        ZStack {
            KUTheme.heroGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 72))
                    .foregroundStyle(KUTheme.white)
                    .accessibilityHidden(true)

                Text("Already Enrolled")
                    .font(KUTheme.titleFont)
                    .foregroundStyle(KUTheme.white)

                Text("Banner ID \(viewModel.bannerID) already has an active face enrollment.")
                    .font(KUTheme.bodyFont)
                    .foregroundStyle(KUTheme.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("If you need to re-enroll (for example after a device change), please contact KU IT services.")
                    .font(KUTheme.captionFont)
                    .foregroundStyle(KUTheme.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button("Done") {
                    onFinish()
                }
                .buttonStyle(KUFilledButtonStyle())
                .padding(.top, 14)
            }
        }
    }

    // MARK: - Timed out / error

    private var timedOutStage: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(KUTheme.white)
                Text("Capture timed out")
                    .font(KUTheme.titleFont)
                    .foregroundStyle(KUTheme.white)
                Text("Only \(viewModel.capturedCount) frames were accepted. Try again with better lighting.")
                    .font(KUTheme.captionFont)
                    .foregroundStyle(KUTheme.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Try again") {
                    viewModel.resetCapture()
                    if viewModel.isDemoMode {
                        viewModel.startDemoCapture()
                    }
                }
                .buttonStyle(KUFilledButtonStyle())
                .padding(.top, 8)
            }
        }
    }

    private func errorStage(_ message: String) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(KUTheme.white)
                Text(message)
                    .font(KUTheme.bodyFont)
                    .foregroundStyle(KUTheme.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if viewModel.canRetryUpload {
                    Button("Try Again") {
                        viewModel.retryUpload()
                    }
                    .buttonStyle(KUFilledButtonStyle())
                    .padding(.top, 8)
                }
                Button("Back") {
                    dismiss()
                }
                .buttonStyle(KUOutlineButtonStyle())
            }
        }
    }
}

// MARK: - Scanner

/// Animated horizontal scan line sweeping top → bottom. The area is transparent.
struct ScannerScanLine: View {
    @State private var position: CGFloat = 0.2

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(KUTheme.white.opacity(0.9))
                .shadow(color: KUTheme.blue.opacity(0.9), radius: 8)
                .position(x: geo.size.width / 2, y: geo.size.height * position)
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                position = 0.85
            }
        }
    }
}

// MARK: - Button styles

struct KUFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KUTheme.bodyFont.bold())
            .foregroundStyle(KUTheme.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(KUTheme.blue, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct KUOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KUTheme.bodyFont.bold())
            .foregroundStyle(KUTheme.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(KUTheme.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(KUTheme.white.opacity(0.6), lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

#Preview {
    FaceEnrollmentView(bannerID: "100012345")
}