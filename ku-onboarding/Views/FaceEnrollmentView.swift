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

    init(bannerID: String) {
        _viewModel = StateObject(wrappedValue: FaceEnrollmentViewModel(bannerID: bannerID))
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
            ? "Simulator Detected"
            : (camera.isAuthorized ? "Camera Ready" : "Camera Access Required")
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
            : "Capturing your face"
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

                Text("Thank You!!")
                    .font(KUTheme.displayFont)
                    .foregroundStyle(KUTheme.white)

                Text("Your face is enrolled")
                    .font(KUTheme.titleFont)
                    .foregroundStyle(KUTheme.white.opacity(0.95))

                Text(viewModel.bannerID)
                    .font(KUTheme.bodyFont.bold())
                    .foregroundStyle(KUTheme.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(KUTheme.white.opacity(0.2), in: Capsule())

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(KUFilledButtonStyle())
                .padding(.top, 18)
            }
            .padding(24)
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
                Button("Back") {
                    dismiss()
                }
                .buttonStyle(KUFilledButtonStyle())
                .padding(.top, 8)
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