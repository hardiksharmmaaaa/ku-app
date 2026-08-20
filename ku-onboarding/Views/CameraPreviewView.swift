//
//  CameraPreviewView.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 20/08/26.
//
//  Bridges AVCaptureVideoPreviewLayer into SwiftUI using a UIViewRepresentable.

import SwiftUI
import UIKit
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let service: CameraService

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = service.sessionObject
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== service.sessionObject {
            uiView.previewLayer.session = service.sessionObject
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}