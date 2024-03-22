//
//  QRCodeController.swift
//  Calliope App
//
//  Created by itestra on 12.12.23.
//  Copyright © 2023 calliope. All rights reserved.
//

import UIKit
import AVFoundation

class QRCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet var cameraView: PreviewView!
    @IBOutlet var openMakeCodeButton: UIButton!
    @IBOutlet var qrCodeFrameView: UIView!
    
    var foundQrCodeString: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try cameraView.initializeSession(delegate: self)
        } catch {
            self.navigationController?.popViewController(animated: true)
        }
        openMakeCodeButton.isHidden = true
        qrCodeFrameView.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
        qrCodeFrameView.layer.borderWidth = 2
        view.addSubview(qrCodeFrameView)
        openMakeCodeButton.isHidden = true
    }
    
    public func changeQrCodeFrameViewStaten(isHidden: Bool) {
        UIView.animate(withDuration: 0.5) {
            self.qrCodeFrameView.alpha = isHidden ? 0.0 : 1.0
            self.qrCodeFrameView.layer.borderWidth = isHidden ? 2 : 4
        } completion: { finished in
            if finished {
                self.qrCodeFrameView.isHidden = isHidden
            }
        }
        self.qrCodeFrameView.isHidden = isHidden
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) -> Void in
            self.cameraView.layoutView()
        }, completion: { (context) -> Void in
            
        })
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            changeQrCodeFrameViewStaten(isHidden: true)
            return
        }

        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            guard let barCodeObject = cameraView.previewLayer.transformedMetadataObject(for: metadataObj) else {
                return
            }
            changeQrCodeFrameViewStaten(isHidden: false)
            qrCodeFrameView.frame = self.view.convert(barCodeObject.bounds, from: cameraView.coordinateSpace)
            // ToDo: Extend Validation of URLs
            if let stringValue = metadataObj.stringValue, stringValue.lowercased().contains("makecode"){
                openMakeCodeButton.isHidden = false
                foundQrCodeString = stringValue
            } else if let stringValue = metadataObj.stringValue, stringValue.contains(".hex") {
                openMakeCodeButton.isHidden = true
                foundQrCodeString = stringValue
            } else {
                openMakeCodeButton.isHidden = true
                foundQrCodeString = ""
            }
        }
    }
    
    @IBSegueAction func createMakecodeEditor(_ coder: NSCoder, sender: Any?) -> EditorViewController? {
        let editor = MakeCode()
        editor.url = URL.init(string: foundQrCodeString)
        return EditorViewController(coder: coder, editor: editor)
    }
}


class PreviewView: UIView, AVCaptureMetadataOutputObjectsDelegate {

    // Use AVCaptureVideoPreviewLayer as the view's backing layer.
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var device: AVCaptureDevice?
    var output: AVCaptureMetadataOutput?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    
    public func initializeSession(delegate: AVCaptureMetadataOutputObjectsDelegate) throws {
        self.session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: AVMediaType.video), let input = try? AVCaptureDeviceInput(device: device), let session = session else {
            throw "Cannot capture video"
        }
        
        session.addInput(input)
        let captureMetadataOutput = AVCaptureMetadataOutput()
        session.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        previewLayer.videoGravity = .resizeAspectFill
        layoutView()
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    // Connect the layer to a capture session.
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set {
            previewLayer.session?.stopRunning()
            guard let session = newValue else {
                previewLayer.session = nil
                return
            }
            
            previewLayer.session = session
        }
    }
    
    public func transformMetaDataObjetToBarCodeObject(metaDataObject: AVMetadataMachineReadableCodeObject) -> AVMetadataObject? {
        return previewLayer.transformedMetadataObject(for: metaDataObject)
    }
    
    public func layoutPreviewLayer(orientation: AVCaptureVideoOrientation) {
        previewLayer.connection?.videoOrientation = orientation
    }
    
    public func layoutView() {
        self.previewLayer.connection?.videoOrientation = self.transformOrientation(orientation: UIDevice.current.orientation)
        self.previewLayer.frame.size = self.frame.size
    }
    
    func transformOrientation(orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
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
