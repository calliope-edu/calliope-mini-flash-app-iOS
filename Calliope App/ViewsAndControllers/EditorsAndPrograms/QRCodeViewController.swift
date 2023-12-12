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
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet var openMakeCodeButton: UIButton!
    @IBOutlet var downloadHexButton: UIButton!
    
    var qrCodeFrameView: UIView?
    
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMetadataOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var foundQrCodeString: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        openMakeCodeButton.isHidden = true
        downloadHexButton.isHidden = true
        qrCodeFrameView?.frame = CGRect.zero
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraView.isHidden = true
        createSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        previewLayer?.frame.size = cameraView.frame.size
        qrCodeFrameView = UIView()
        
        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
            qrCodeFrameView.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView)
            view.bringSubviewToFront(qrCodeFrameView)
        }
        cameraView.isHidden = false
        
        openMakeCodeButton.isHidden = true
        downloadHexButton.isHidden = true
        qrCodeFrameView?.frame = CGRect.zero
    }
    
    func createSession() {
        session = AVCaptureSession()
        device = AVCaptureDevice.default(for: AVMediaType.video)
        
        do{
            input = try AVCaptureDeviceInput(device: device!)
        }
        catch{
            LogNotify.log("Failed getting AVCaptureDeviceInput")
        }
        
        if let input = input{
            session?.addInput(input)
        }
        
        let captureMetadataOutput = AVCaptureMetadataOutput()
        session?.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session!)
        previewLayer?.frame.size = cameraView.frame.size
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.connection?.videoOrientation = transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!)
        
        cameraView.layer.addSublayer(previewLayer!)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session?.startRunning()
        }
    }
    
    func getCameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTelephotoCamera, .builtInTrueDepthCamera, .builtInWideAngleCamera, ], mediaType: .video, position: .back)
        
        if let device = deviceDiscoverySession.devices.first {
            return device
        }
        return nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) -> Void in
            self.previewLayer?.connection?.videoOrientation = self.transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!)
            self.previewLayer?.frame.size = self.cameraView.frame.size
        }, completion: { (context) -> Void in
            
        })
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    func transformOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }

        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            guard let barCodeObject = previewLayer?.transformedMetadataObject(for: metadataObj) else {
                return
            }
            qrCodeFrameView?.frame = barCodeObject.bounds
            
            // ToDo: Extend Validation of URLs
            if let stringValue = metadataObj.stringValue, stringValue.lowercased().contains("makecode"){
                openMakeCodeButton.isHidden = false
                downloadHexButton.isHidden = true
                foundQrCodeString = stringValue
                print("Found Metadata Object")
            } else if let stringValue = metadataObj.stringValue, stringValue.contains(".hex") {
                openMakeCodeButton.isHidden = true
                downloadHexButton.isHidden = false
            } else {
                openMakeCodeButton.isHidden = true
                downloadHexButton.isHidden = true
                qrCodeFrameView?.frame = CGRect.zero
            }
        }
    }
    
    @IBSegueAction func createMakecodeEditor(_ coder: NSCoder, sender: Any?) -> EditorViewController? {
        var editor = MakeCode()
        editor.url = URL.init(string: foundQrCodeString)
        return EditorViewController(coder: coder, editor: editor)
    }
    
    @IBAction func uploadDefaultProgram(_ sender: Any) {
        if foundQrCodeString.isEmpty {
            return
        }
        let program = QRCodeHexFile.init(url: foundQrCodeString)
        FirmwareUpload.showUIForDownloadableProgram(controller: self, program: program)
    }
}
