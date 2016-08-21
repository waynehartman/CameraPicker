//
//  CameraController.swift
//  Camera Picker
//
//  Created by Wayne Hartman on 8/21/16.
//  Copyright © 2016 Wayne Hartman. All rights reserved.
//

import UIKit
import AVFoundation

typealias CameraControllerCaptureHandler = (UIImage?, Error?) -> ()

internal class CameraController: NSObject {

    //  Internal vars
    internal var previewLayer: AVCaptureVideoPreviewLayer
    internal var previewAspectRatio = CGSize(width: 0, height: 0)
    internal var hasBackCamera: Bool {
        get {
            return self.backCamera != nil
        }
    }

    // Private vars
    private let session = AVCaptureSession()
    private let stillImageOutput = AVCaptureStillImageOutput() // Update this for iOS 10...
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    
    override init() {
        self.session.sessionPreset = AVCaptureSessionPresetPhoto
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]

        super.init()

        self.updateDevices()
        self.connectCurrentDevice()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateDevices), name: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRotationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)

        defer {
            self.session.startRunning()
        }
    }
    
    // MARK: Internal Methods
    internal func takePhoto(completion: CameraControllerCaptureHandler) {
        let connection = self.stillImageOutput.connection(withMediaType: AVMediaTypeVideo)
        let deviceOrientation = UIDevice.current.orientation

        self.stillImageOutput.captureStillImageAsynchronously(from: connection, completionHandler:{ (sampleBuffer: CMSampleBuffer?, error: Error?) in
            guard let buffer = sampleBuffer else {
                completion(nil, error)
                return
            }
            
            DispatchQueue.main.async(execute: {
                var imageOrientation = UIImageOrientation.right
                
                switch (deviceOrientation) {
                case .portrait:
                    imageOrientation = .right
                case .portraitUpsideDown:
                    imageOrientation = .left
                case .landscapeLeft:
                    imageOrientation = .up
                case .landscapeRight:
                    imageOrientation = .down
                default:
                    imageOrientation = .right
                }
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer) as CFData
                let dataProvider = CGDataProvider(data: imageData)

                let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
                let image = UIImage(cgImage: cgImageRef!, scale: 1.0, orientation: imageOrientation)

                completion(image, nil)
            })
        })
    }
    
    internal func toggleCamera() {
        self.session.beginConfiguration()
        
        self.currentCamera = self.currentCamera == self.frontCamera ? self.backCamera : self.frontCamera
        self.connectCurrentDevice()
        
        self.session.commitConfiguration()
    }
    
    private func updatePreviewOrientation() {
        let deviceOrientation = UIDevice.current.orientation

        let updateConnection = {(connection: AVCaptureConnection, deviceOrientation: UIDeviceOrientation)  in
            let isOrientationSupported = connection.isVideoOrientationSupported
            if !isOrientationSupported {
                return;
            }

            var connectionOrientation = connection.videoOrientation

            switch (deviceOrientation) {
            case .portrait:
                connectionOrientation = .portrait
                break
            case .portraitUpsideDown:
                connectionOrientation = .portraitUpsideDown
                break
            case .landscapeLeft:
                connectionOrientation = .landscapeRight
                break
            case .landscapeRight:
                connectionOrientation = .landscapeLeft
                break
            default :
                break
            }

            connection.videoOrientation = connectionOrientation
        }

        if let connection = self.stillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
            updateConnection(connection, deviceOrientation)
        }
        
        if let connection = self.previewLayer.connection {
            updateConnection(connection, deviceOrientation)
        }
    }

    internal func focus(at point: CGPoint) {
        if let camera = self.currentCamera {
            let focusPoint = CGPoint(x: point.x / self.previewLayer.frame.size.width,
                                     y: point.y / self.previewLayer.frame.size.height)

            do {
                try camera.lockForConfiguration()
                camera.focusPointOfInterest = focusPoint
                camera.unlockForConfiguration()
            } catch {
                
            }
        }
    }

    // MARK: Private Methods
    private func connectCurrentDevice() {
        guard let currentCamera = self.currentCamera else {
            return
        }

        do {
            for existingInput in self.session.inputs {
                if let input = existingInput as? AVCaptureDeviceInput {
                    self.session.removeInput(input)
                }
            }

            let input = try AVCaptureDeviceInput(device: currentCamera)

            self.session.addInput(input)

            if self.session.outputs.count == 0 {
                self.session.addOutput(self.stillImageOutput)
            }

            self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect
            //            self.previewLayer.connection.videoOrientation = .portrait

            if let camera = self.currentCamera {
                let dimensions = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription);
                self.previewAspectRatio = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
            }
        } catch {
            print("error making connection:\(error)")
        }
    }
    
    @objc private func deviceRotationDidChange() {
        let orientation = UIDevice.current.orientation
        
        print("Orientation changed: \(orientation)")
        
        self.updatePreviewOrientation()
    }
    
    @objc private func updateDevices() {
        let captureDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        
        guard let devices = captureDevices else {
            print("No devices....")
            return
        }
        
        var frontCamera: AVCaptureDevice? = nil
        var backCamera: AVCaptureDevice? = nil
        
        for captureDevice in devices {
            if let device = captureDevice as? AVCaptureDevice {
                switch device.position {
                case .front:
                    frontCamera = device
                case .back:
                    backCamera = device
                case .unspecified:
                    break
                }
            }
        }
        
        self.frontCamera = frontCamera
        self.backCamera = backCamera
        
        // Default to the back camera
        if self.currentCamera == nil {
            self.currentCamera = self.backCamera
        }
    }
}
