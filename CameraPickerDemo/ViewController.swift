//
//  ViewController.swift
//  CameraPickerDemo
//
//  Created by Wayne Hartman on 8/20/16.
//  Copyright © 2016 Wayne Hartman. All rights reserved.
//

import UIKit
import CameraPicker

class ViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            return .all
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }

    @IBAction func didSelectShowPicker(_ sender: AnyObject) {
        let cameraPickerVC = CameraPickerViewController()
        cameraPickerVC.imageSelectionHandler = {(image: UIImage?) in
            self.imageView.image = image
        }

        self.present(cameraPickerVC, animated: true, completion: nil)
    }
}

