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
    private var isManualLayout = true
    private let cameraController = CameraController()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.black

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

        self.layer.insertSublayer(self.cameraController.previewLayer, at: 0)

        self.clipsToBounds = true

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap(sender:)))
        self.addGestureRecognizer(tapRecognizer)
    }

    override internal func layoutSubviews() {
        self.cameraController.previewLayer.frame = self.bounds

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
        self.cameraController.toggleCamera()
    }
    
    @objc private func didTap(sender: UITapGestureRecognizer) {
        let touchPoint = sender.location(in: self)

        self.cameraController.focus(at: touchPoint)
    }
}
