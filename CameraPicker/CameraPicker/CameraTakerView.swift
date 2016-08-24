//
//  CameraTakerView.swift
//  Camera Picker
//
//  Created by Wayne Hartman on 8/20/16.
//  Copyright © 2016 Wayne Hartman. All rights reserved.
//

import UIKit
import AVFoundation

internal typealias CameraTakerViewCaptureHandler = (UIImage?, Error?) -> (Void)

internal class CameraTakerView : UIView {
    internal var captureHandler: CameraTakerViewCaptureHandler?
    internal var previewAspectRatio: CGSize {
        get {
            return self.cameraController.previewAspectRatio
        }
    }

    @IBOutlet private var takeButton: UIButton! = UIButton(frame: CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0))
    @IBOutlet private var flipButton: UIButton! = UIButton(frame: CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0))
    @IBOutlet private var previewView: UIView!
    private var isManualLayout = true
    private let cameraController = CameraController()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.black

        let previewView = UIView(frame: self.bounds)
        previewView.backgroundColor = UIColor.clear
        previewView.layer.addSublayer(self.cameraController.previewLayer)
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

    override internal func layoutSubviews() {
        self.previewView.frame = self.bounds
        self.cameraController.previewLayer.frame = self.previewView.bounds
        self.flipButton.isHidden = !self.cameraController.hasBackCamera

        if self.isManualLayout {
            self.takeButton.center = CGPoint(x: self.frame.size.width * 0.5,
                                             y: self.frame.size.height - (self.takeButton.frame.size.height * 0.5) - 4.0)
            self.flipButton.center = CGPoint(x:self.frame.size.width - (self.flipButton.frame.size.width * 0.5),
                                             y: (self.flipButton.frame.size.height * 0.5))
        }

        super.layoutSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        self.isManualLayout = false
        super.init(coder: aDecoder)
    }

    @objc private func takePicture(sender: Any) {
        self.takeButton.isEnabled = false
        
        self.cameraController.takePhoto { (image: UIImage?, error: Error?) in
            if let captureHandler = self.captureHandler {
                self.takeButton.isEnabled = true
                captureHandler(image, error)
            }
        }
    }
    
    @objc private func flipCamera(sender: Any) {
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
    
    @objc private func didTap(sender: UITapGestureRecognizer) {
        let touchPoint = sender.location(in: self)

        self.cameraController.focus(at: touchPoint)
    }
}
