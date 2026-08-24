//
//  CameraService.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Wraps AVCaptureSession with front/back camera switching, exposes an
//  AVCaptureVideoPreviewLayer for SwiftUI and streams sample buffers to a
//  handler for Vision-based quality gating.

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class CameraService: NSObject, ObservableObject {

    @Published private(set) var isAuthorized = false
    @Published private(set) var isRunning = false
    @Published private(set) var unavailableReason: String?
    @Published private(set) var currentPosition: AVCaptureDevice.Position = .front

    /// True when no camera device exists at all (e.g. running in the iOS Simulator).
    var hasNoCameraDevice: Bool {
        allAvailablePositions.isEmpty
    }

    /// Positions physically present on this device.
    private var allAvailablePositions: [AVCaptureDevice.Position] {
        let positions: [AVCaptureDevice.Position] = [.front, .back]
        return positions.filter { availableDevice(for: $0) != nil }
    }

    /// Called on the main actor with every video sample buffer while the session runs.
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    private let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
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

        guard let device = availableDevice(for: currentPosition) else {
            unavailableReason = "No camera available. Face enrollment requires a physical iPhone."
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

            videoInput = input
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

    // MARK: - Camera switching

    /// Switches between the front and back camera while keeping the session
    /// running so the preview never blinks more than a frame.
    func switchCamera() {
        let next = currentPosition == .front ? AVCaptureDevice.Position.back : .front
        guard next != currentPosition, let device = availableDevice(for: next) else { return }
        guard let existingInput = videoInput else { return }

        let wasRunning = isRunning

        session.beginConfiguration()
        session.removeInput(existingInput)

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                session.addInput(existingInput)
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            videoInput = input
            currentPosition = next
        } catch {
            session.addInput(existingInput)
        }

        session.commitConfiguration()

        // Ensure video orientation stays correct after camera switch
        videoOutput?.connection(with: .video)?.videoOrientation = .portrait

        if wasRunning && !session.isRunning {
            session.startRunning()
        }
        isRunning = session.isRunning
    }

    // MARK: - Device lookup

    private func availableDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .front {
            return AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        return AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
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