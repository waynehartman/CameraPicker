//
//  CameraController.swift
//  Camera Picker

/*
 *  Copyright (c) 2016, Wayne Hartman
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit
import AVFoundation

typealias CameraControllerCaptureHandler = (UIImage?, Error?) -> ()

/// Controller class for managing the camera
internal class CameraController: NSObject {

    //  Internal vars
    internal var previewLayer: AVCaptureVideoPreviewLayer
    internal var previewAspectRatio = CGSize(width: 0, height: 0)
    internal var currentCamera: AVCaptureDevice?
    internal var hasBackCamera: Bool {
        get {
            return self.backCamera != nil
        }
    }

    // Private vars
    fileprivate let session = AVCaptureSession()
    fileprivate let stillImageOutput = AVCaptureStillImageOutput() // Update this for iOS 10...
    fileprivate var frontCamera: AVCaptureDevice?
    fileprivate var backCamera: AVCaptureDevice?
    
    override init() {
        self.session.sessionPreset = AVCaptureSessionPresetPhoto
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]

        super.init()

        self.updateDevices()
        self.connectCurrentDevice()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateDevices), name: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRotationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }

    internal func startCamera() {
        if !self.session.isRunning {
            self.session.startRunning()
        }

        // Get the camera updated to the correct orientation
        self.deviceRotationDidChange()
    }

    // MARK: Internal Methods
    internal func takePhoto(completion: @escaping CameraControllerCaptureHandler) {
        let connection = self.stillImageOutput.connection(withMediaType: AVMediaTypeVideo)
        let deviceOrientation = UIDevice.current.orientation

        weak var weakSelf = self

        self.stillImageOutput.captureStillImageAsynchronously(from: connection, completionHandler:{ (sampleBuffer: CMSampleBuffer?, error: Error?) in
            guard let buffer = sampleBuffer, let strongSelf = weakSelf else {
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
                    if strongSelf.currentCamera == strongSelf.frontCamera {
                        imageOrientation = .down
                    } else {
                        imageOrientation = .up
                    }
                case .landscapeRight:
                    if strongSelf.currentCamera == strongSelf.frontCamera {
                        imageOrientation = .up
                    } else {
                        imageOrientation = .down
                    }
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

    internal func focus(at point: CGPoint) {
        if let camera = self.currentCamera {
            guard camera.isFocusPointOfInterestSupported else {
                return
            }

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

    deinit {
        print("CameraController destroyed")
    }
}

// MARK: 
// MARK: Private Functions
// MARK: 
extension CameraController {
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
    
    fileprivate func connectCurrentDevice() {
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
            
            self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            
            if let camera = self.currentCamera {
                let dimensions = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription);
                self.previewAspectRatio = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
            }
        } catch {
            print("error making connection:\(error)")
        }
    }
    
    @objc fileprivate func deviceRotationDidChange() {
        let orientation = UIDevice.current.orientation
        
        print("Orientation changed: \(orientation)")
        
        self.updatePreviewOrientation()
    }
    
    @objc fileprivate func updateDevices() {
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
