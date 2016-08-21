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
    @IBOutlet var cameraPicker: CameraPicker.CameraPickerView!
    @IBOutlet var imageView: UIImageView!
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            return .all
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let cameraPickerItem = PickerItem.cameraPickerItem {
            print("Camera!")
        }
        let photoPickerItem = PickerItem.photoLibraryPickerItem {
            print("Photo Picker!")
        }

        self.cameraPicker.pickerItems.append(contentsOf: [cameraPickerItem, photoPickerItem])

        self.cameraPicker.imageSelectionHandler = {(image: UIImage?) in
            self.imageView.image = image
        }
    }
}

