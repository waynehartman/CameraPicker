//
//  CameraPickerViewController.swift
//  Camera Picker
//
//  Created by Wayne Hartman on 8/24/16.
//  Copyright © 2016 Wayne Hartman. All rights reserved.
//

import UIKit

public typealias CameraPickerViewControllerCancelHandler = (Void) -> (Void)

public class CameraPickerViewController : UIViewController {
    public var cancelHandler: CameraPickerViewControllerCancelHandler?
    public var imageSelectionHandler: CameraPickerImageSelectionHandler?

    override public var modalPresentationStyle: UIModalPresentationStyle {
        get {
            return .overCurrentContext
        } set {
            self.modalPresentationStyle = .overCurrentContext
        }
    }
    override public var transitioningDelegate: UIViewControllerTransitioningDelegate? {
        get {
            return self
        } set {
            self.transitioningDelegate = self
        }
    }

    fileprivate var pickerView = CameraPickerView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 253.0))
    fileprivate var isPresenting = true
    fileprivate var isTransitioning = false
    fileprivate var dismissView: UIView!

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        let cameraPickerItem = PickerItem.cameraPickerItem {
            let cameraPicker = UIImagePickerController()
            cameraPicker.sourceType = UIImagePickerControllerSourceType.camera
            cameraPicker.cameraCaptureMode = .photo
            cameraPicker.delegate = self

            self.present(cameraPicker, animated: true, completion: nil)
        }
        
        let photoPickerItem = PickerItem.photoLibraryPickerItem {
            let cameraPicker = UIImagePickerController()
            cameraPicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            cameraPicker.delegate = self

            self.present(cameraPicker, animated: true, completion: nil)
        }

        self.pickerView.pickerItems.append(contentsOf: [cameraPickerItem, photoPickerItem])
        self.pickerView.imageSelectionHandler = {(image: UIImage?) in
            if let imageHandler = self.imageSelectionHandler {
                self.presentingViewController?.dismiss(animated: true, completion: { 
                    imageHandler(image)
                })
            }
        }

        self.view.translatesAutoresizingMaskIntoConstraints = true
        self.view.addSubview(self.pickerView)

        let dismissView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 100.0))
        dismissView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        let dismissGesture = UITapGestureRecognizer(target: self, action: #selector(didTapDismissView(sender:)))
        dismissView.addGestureRecognizer(dismissGesture)
        self.dismissView = dismissView

        self.view.addSubview(self.dismissView)
    }

    override public func viewDidLayoutSubviews() {
        

        super.viewDidLayoutSubviews()
    }
    
    override public func viewWillLayoutSubviews() {
        if !isTransitioning {
            let pickerHeight: CGFloat = 253.0
            let pickerFrame = CGRect(x: 0.0,
                                     y: self.view.frame.size.height - pickerHeight,
                                     width: self.view.frame.size.width,
                                     height: pickerHeight)
            self.pickerView.frame = pickerFrame
            
            let dismissFrame = CGRect(x: CGFloat(0.0),
                                      y: CGFloat(0.0),
                                      width: self.view.frame.size.width,
                                      height: self.view.frame.size.height - self.pickerView.frame.size.height)
            self.dismissView.frame = dismissFrame
        }
        
        super.viewWillLayoutSubviews()
    }

    //MARK:
    //MARK: Private Methods
    //MARK:

    @objc private func didTapDismissView(sender: Any) {
        self.presentingViewController!.dismiss(animated: true, completion: self.cancelHandler)
    }
}

extension CameraPickerViewController : UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.isPresenting = true
        
        return self
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        self.isPresenting = false
        
        return self
    }
}

extension CameraPickerViewController : UIViewControllerAnimatedTransitioning {
    private func animationDuration() -> TimeInterval {
        return TimeInterval(0.25)
    }

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.animationDuration()
    }
    
    // This method can only  be a nop if the transition is interactive and not a percentDriven interactive transition.
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView

        var dismissStartOpacity: CGFloat = 0.0
        var dismissEndOpacity: CGFloat = 1.0
        var dismissStartRect = self.view.bounds
        var dismissEndRect = CGRect(x: CGFloat(0.0),
                                    y: CGFloat(0.0),
                                    width: self.view.frame.size.width,
                                    height: self.view.frame.size.height - self.pickerView.frame.size.height)

        var pickerStartTranslation = CGAffineTransform.init(translationX: CGFloat(0.0), y: self.pickerView.frame.size.height)
        var pickerEndTranslation = CGAffineTransform.identity

        if self.isPresenting {
            containerView.addSubview(self.view)
        }

        let isPresenting = self.isPresenting

        if !isPresenting {
            swap(&dismissStartOpacity, &dismissEndOpacity)
            swap(&dismissStartRect, &dismissEndRect)
            swap(&pickerStartTranslation, &pickerEndTranslation)
        }
        
        self.view.layoutIfNeeded() // Get everything laid out the way it needs to be before making transforms
        self.isTransitioning = true

        self.dismissView.alpha = dismissStartOpacity
        self.dismissView.frame = dismissStartRect
        self.pickerView.transform = pickerStartTranslation

        UIView.animate(withDuration: self.animationDuration(), animations: {
            self.pickerView.transform = pickerEndTranslation
            self.dismissView.alpha = dismissEndOpacity
            self.dismissView.frame = dismissEndRect
        }) { (wasCancelled: Bool) in
            if !isPresenting {
                self.view.removeFromSuperview()
            }
            
            self.isTransitioning = false
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

extension CameraPickerViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        var image = info[UIImagePickerControllerEditedImage] as? UIImage

        if image == nil {
            image = info[UIImagePickerControllerOriginalImage] as? UIImage
        }

        if let imageHandler = self.imageSelectionHandler {
            imageHandler(image)
        }
        
        self.dismiss(animated: true) {
            self.presentingViewController!.dismiss(animated: true, completion:nil)
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}
