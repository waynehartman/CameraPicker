//
//  CameraTakerView.swift
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

internal typealias CameraTakerViewCaptureHandler = (UIImage?, Error?) -> (Void)


/// Private UIView for containing an instance of an AVCaptureVideoPreviewLayer
fileprivate class CameraPreviewView : UIView {
    var previewLayer: AVCaptureVideoPreviewLayer!
    var captureDevice: AVCaptureDevice? {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }

    class func cameraPreviewView(previewLayer: AVCaptureVideoPreviewLayer, device: AVCaptureDevice?) -> CameraPreviewView {
        let previewView = CameraPreviewView(frame:previewLayer.bounds)
        previewView.previewLayer = previewLayer
        previewView.captureDevice = device

        previewView.layer.addSublayer(previewLayer)

        return previewView
    }

    override var intrinsicContentSize: CGSize {
        get {
            if let device = self.captureDevice {
                let size = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
            } else {
                return self.previewLayer.frame.size
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        self.previewLayer.frame = self.bounds
    }
}

internal class CameraTakerView : UIView {
    internal var captureHandler: CameraTakerViewCaptureHandler?
    internal var previewAspectRatio: CGSize {
        get {
            return self.cameraController.previewAspectRatio
        }
    }

    override var intrinsicContentSize: CGSize {
        get {
            return self.previewView.intrinsicContentSize
        }
    }

    @IBOutlet fileprivate var takeButton: UIButton! = UIButton(frame: CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0))
    @IBOutlet fileprivate var flipButton: UIButton! = UIButton(frame: CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0))
    @IBOutlet fileprivate var previewView: UIView!
    fileprivate var isManualLayout = true
    fileprivate let cameraController = CameraController()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.black

        let previewView = CameraPreviewView.cameraPreviewView(previewLayer: self.cameraController.previewLayer, device: self.cameraController.currentCamera)
        previewView.backgroundColor = UIColor.clear
        self.addSubview(previewView)

        self.previewView = previewView

        self.addSubview(self.takeButton)
        self.addSubview(self.flipButton)

        let bundle = Bundle(for: CameraTakerView.self)
        let takeImage = UIImage(named: "shutter", in: bundle, compatibleWith: nil)
        let flipImage = UIImage(named: "cameraToggle", in: bundle, compatibleWith: nil)

        self.takeButton.tintColor = UIColor.white
        self.takeButton.setImage(takeImage, for: .normal)

        self.flipButton.tintColor = UIColor.white
        self.flipButton.setImage(flipImage, for: .normal)

        self.takeButton.addTarget(self, action: #selector(takePicture(sender:)), for: .touchUpInside)
        self.flipButton.addTarget(self, action: #selector(flipCamera(sender:)), for: .touchUpInside)

        self.clipsToBounds = true

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap(sender:)))
        self.addGestureRecognizer(tapRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        self.isManualLayout = false
        super.init(coder: aDecoder)
    }

    deinit {
        print("CameraTakerView destroyed")
    }

    override internal func layoutSubviews() {
        self.previewView.frame = self.bounds
        self.cameraController.previewLayer.frame = self.previewView.bounds
        self.flipButton.isHidden = !self.cameraController.hasBackCamera

        if self.isManualLayout {
            let width = self.frame.size.width
            let height = self.frame.size.height

            let isLandscape = height < width

            let takeMargin: CGFloat = 4.0

            var takeX = width * 0.5
            var takeY = height - (self.takeButton.frame.size.height * 0.5) - takeMargin
            
            var flipX = width - (self.flipButton.frame.size.width * 0.5)
            var flipY = (self.flipButton.frame.size.height * 0.5)

            if isLandscape {
                takeX = width - (self.takeButton.frame.size.width * 0.5) - takeMargin
                takeY = height * 0.5

                flipX = (self.flipButton.frame.size.width * 0.5)
                flipY = (self.flipButton.frame.size.height * 0.5)
            }

            self.takeButton.center = CGPoint(x: takeX,
                                             y: takeY)
            self.flipButton.center = CGPoint(x: flipX,
                                             y: flipY)
        }

        super.layoutSubviews()
    }
    
    override internal func didMoveToWindow() {
        super.didMoveToWindow()

        self.cameraController.startCamera()
    }
}

extension CameraTakerView {
    @objc fileprivate func takePicture(sender: Any) {
        self.takeButton.isEnabled = false
        
        self.cameraController.takePhoto { (image: UIImage?, error: Error?) in
            if let captureHandler = self.captureHandler {
                self.takeButton.isEnabled = true
                captureHandler(image, error)
            }
        }
    }
    
    @objc fileprivate func flipCamera(sender: Any) {
        if let snapshot = self.previewView.snapshotView(afterScreenUpdates: true) {
            let triggerButtonZPosition = self.takeButton.layer.zPosition
            let flipButtonZPosition = self.flipButton.layer.zPosition
            
            let zPosition = CGFloat(1000)
            self.takeButton.layer.zPosition = zPosition
            self.flipButton.layer.zPosition = zPosition
            
            self.insertSubview(snapshot, aboveSubview: self.previewView)
            
            let perspective = CGFloat(1.0 / 500.0);
            let angle = CGFloat(M_PI * 0.5)
            let scale = CGFloat(0.75)
            
            let scaleMatrix = CATransform3DMakeScale(scale, scale, scale)
            
            var fromMatrix = CATransform3DMakeRotation(angle, 0.0, 1.0, 0.0)
            fromMatrix.m34 = perspective
            fromMatrix = CATransform3DConcat(fromMatrix, scaleMatrix)
            
            var toMatrix = CATransform3DMakeRotation(-angle, 0.0, 1.0, 0.0)
            toMatrix.m34 = perspective
            toMatrix = CATransform3DConcat(toMatrix, scaleMatrix)
            
            self.previewView.isHidden = true
            
            let duration = 0.33
            
            UIView.animate(withDuration: duration * 0.5, animations: {
                snapshot.layer.transform = fromMatrix
                
            }, completion: { (didFinish: Bool) in
                
                snapshot.removeFromSuperview()
                self.previewView.layer.transform = toMatrix
                self.previewView.isHidden = false
                
                UIView.animate(withDuration: duration * 0.5, animations: {
                    self.previewView.layer.transform = CATransform3DIdentity
                    
                }, completion: { (didFinish: Bool) in
                    self.takeButton.layer.zPosition = triggerButtonZPosition
                    self.flipButton.layer.zPosition = flipButtonZPosition
                })
            })
        }
        
        self.cameraController.toggleCamera()
    }
    
    @objc fileprivate func didTap(sender: UITapGestureRecognizer) {
        let touchPoint = sender.location(in: self)
        
        self.cameraController.focus(at: touchPoint)
    }
}
