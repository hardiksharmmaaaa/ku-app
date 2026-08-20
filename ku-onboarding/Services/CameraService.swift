//
//  CameraService.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Wraps AVCaptureSession for the front camera, exposes an AVCaptureVideoPreviewLayer
//  for SwiftUI and streams sample buffers to a handler for Vision-based quality gating.

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class CameraService: NSObject, ObservableObject {

    @Published private(set) var isAuthorized = false
    @Published private(set) var isRunning = false
    @Published private(set) var unavailableReason: String?

    /// True when authorization was granted but no front camera device exists
    /// (e.g. running in the iOS Simulator).
    var hasNoCameraDevice: Bool {
        AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) == nil
            && AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) == nil
    }

    /// Called on the main actor with every video sample buffer while the session runs.
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    private let session = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?

    override init() {
        super.init()
    }

    var sessionObject: AVCaptureSession { session }

    /// The preview layer bound to the session. Attach it once per view.
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        return layer
    }

    // MARK: - Permissions

    func requestAccess() async {
        let status: AVAuthorizationStatus
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            status = .authorized
        case .notDetermined:
            status = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        case .denied:
            status = .denied
        case .restricted:
            status = .restricted
        @unknown default:
            status = .denied
        }
        isAuthorized = (status == .authorized)
        if !isAuthorized {
            unavailableReason = "Camera access is required to enroll your face. Please allow camera access in Settings."
        }
    }

    // MARK: - Session lifecycle

    func start() {
        guard !isRunning else { return }

        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            unavailableReason = "No front camera available. Face enrollment requires a physical iPhone."
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraError.input }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            output.alwaysDiscardsLateVideoFrames = true
            guard session.canAddOutput(output) else { throw CameraError.output }
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ku.camera.sampleQueue"))
            session.beginConfiguration()
            session.sessionPreset = .hd1280x720
            session.addInput(input)
            session.addOutput(output)
            output.connection(with: .video)?.videoOrientation = .portrait
            session.commitConfiguration()
            videoOutput = output

            session.startRunning()
            isRunning = session.isRunning
        } catch {
            unavailableReason = error.localizedDescription
        }
    }

    func stop() {
        guard isRunning else { return }
        session.stopRunning()
        isRunning = session.isRunning
    }

    enum CameraError: LocalizedError {
        case input, output
        var errorDescription: String? {
            switch self {
            case .input: "Could not attach the camera input."
            case .output: "Could not attach the video output."
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        DispatchQueue.main.async { [weak self] in
            self?.onSampleBuffer?(sampleBuffer)
        }
    }
}