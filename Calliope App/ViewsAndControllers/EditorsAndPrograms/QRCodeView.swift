//
//  QRCodeView.swift
//  Calliope App
//
//  Created by Calliope on 15.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import AVFoundation
import Foundation
import SwiftUI
import Vision

struct QRCodeView: View {
    @StateObject private var camera = CameraManager()
    let openEditor: (_ url: String) -> Void

    var body: some View {

        ZStack {
            CameraPreview(session: camera.session, qrFrame: $camera.qrFrame)
                .onAppear {
                    camera.start()
                }
                .onDisappear {
                    camera.stop()
                }

            VStack(spacing: 0) {
                Spacer()
                VStack {
                    if camera.scannedCode == nil {
                        ProgressView("Searching for QR code")
                    } else {
                        Button("Open program") {
                            camera.stop()
                            openEditor(camera.scannedCode!)
                        }
                    }
                }
                .padding()
                .padding(.horizontal, 16)
                .background(Color.calliopeGreen)
                .foregroundColor(.black)
                .cornerRadius(12)
                .padding()
            }
        }
    }
}

final class CameraManager: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session")  // Otherwise session handling could block the main queue

    @Published var scannedCode: String?
    @Published var qrFrame: AVMetadataMachineReadableCodeObject?

    override init() {
        super.init()
        guard let device = AVCaptureDevice.default(for: AVMediaType.video), let input = try? AVCaptureDeviceInput(device: device)
        else {
            LogNotify.error("Cannot capture video")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(
            self,
            queue: .main
        )
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
    }

    func start() {
        sessionQueue.async {
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            self.session.stopRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {

        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = object.stringValue
        else {
            qrFrame = nil
            return
        }

        if isMakeCodeLink(link: value) {
            scannedCode = value
            qrFrame = object
        } else {
            scannedCode = nil
            qrFrame = nil
        }
    }

    func isMakeCodeLink(link: String) -> Bool {
        return link.lowercased().contains("makecode")
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var qrFrame: AVMetadataMachineReadableCodeObject?

    func makeUIView(context: Context) -> UIKitPreview {
        let view = UIKitPreview()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(
        _ uiView: UIKitPreview,
        context: Context
    ) {
        uiView.updateQRFrame(for: qrFrame)
    }
}

class UIKitPreview: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private let overlayView = UIView()

    private var isObservingOrientation = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = .clear
        overlayView.layer.borderColor = UIColor.green.cgColor
        overlayView.layer.borderWidth = 3
        overlayView.layer.cornerRadius = 4
        overlayView.isHidden = true
        addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.centerXAnchor.constraint(equalTo: centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: centerYAnchor),
            overlayView.widthAnchor.constraint(equalToConstant: 100),
            overlayView.heightAnchor.constraint(equalToConstant: 100),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if isObservingOrientation {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            NotificationCenter.default.removeObserver(self)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        beginObservingOrientationChanges()
        updateVideoOrientation()
    }

    private func beginObservingOrientationChanges() {
        guard !isObservingOrientation else { return }
        isObservingOrientation = true
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @objc private func deviceOrientationDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateVideoOrientation()
        }
    }

    func updateQRFrame(for object: AVMetadataMachineReadableCodeObject?) {
        if object == nil {
            hideQRFrame()
            return
        }

        if object!.type == AVMetadataObject.ObjectType.qr {
            guard let barCodeObject = previewLayer.transformedMetadataObject(for: object!) else { return }

            DispatchQueue.main.async {
                self.overlayView.translatesAutoresizingMaskIntoConstraints = true

                self.overlayView.frame = barCodeObject.bounds
                self.overlayView.isHidden = false
            }
        }
    }

    private func hideQRFrame() {
        DispatchQueue.main.async {
            self.overlayView.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        updateVideoOrientation()
    }

    private func updateVideoOrientation() {
        guard let connection = previewLayer.connection,
            connection.isVideoOrientationSupported
        else { return }

        let videoOrientation: AVCaptureVideoOrientation
        if let interfaceOrientation = self.window?.windowScene?.interfaceOrientation,
            let orientation = Self.videoOrientation(for: interfaceOrientation) {
            videoOrientation = orientation
        } else {
            // Fall back to the physical device orientation while the interface orientation is not available yet
            videoOrientation = Self.videoOrientation(for: UIDevice.current.orientation)
        }

        connection.videoOrientation = videoOrientation
    }

    private static func videoOrientation(for interfaceOrientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation? {
        switch interfaceOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .portrait:
            return .portrait
        default:
            return nil
        }
    }

    private static func videoOrientation(for deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}
