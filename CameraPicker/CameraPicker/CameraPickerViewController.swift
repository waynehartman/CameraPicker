//
//  CameraPickerViewController.swift
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

public typealias CameraPickerViewControllerCancelHandler = () -> (Void)

/// A reference UIViewController implementation for using the CameraPickerView.  If more customization is desired, please feel free to create your own UIViewController subclasses.
public class CameraPickerViewController : UIViewController {
    //MARK:
    @objc public var cancelHandler: CameraPickerViewControllerCancelHandler?
    @objc public var imageSelectionHandler: CameraPickerImageSelectionHandler?
    @objc public var appearance = CameraPickerAppearance.normal {
        didSet {
            self.pickerView.appearance = self.appearance
        }
    }
    
    override public var modalPresentationStyle: UIModalPresentationStyle { // Overridden to enforce overCurrentContext
        get {
            return .overCurrentContext
        } set {
            self.modalPresentationStyle = .overCurrentContext
        }
    }
    override public var transitioningDelegate: UIViewControllerTransitioningDelegate? { // Overriden to enforce itself as the UIViewControllerTransitioningDelegate
        get {
            return self
        } set {
            self.transitioningDelegate = self
        }
    }
    
    fileprivate var pickerView = CameraPickerView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 253.0))
    fileprivate var isPresenting = true
    fileprivate var isTransitioning = false // If we do manual layout during presentations, we get strange layout issues.  This flag prevents layouts during transitions.
    fileprivate var dismissView: UIView!
    fileprivate var addedPickerItems = [PickerItem]()
    fileprivate var hasDoneInitialLayout = false
    
    deinit { // For debug purposes only
        print("CameraPickerViewController destroyed")
    }
}

//MARK:
//MARK: Private Methods
//MARK:

extension CameraPickerViewController {
    @objc fileprivate func didTapDismissView(sender: Any) {
        self.presentingViewController!.dismiss(animated: true, completion: self.cancelHandler)
    }
}

//MARK:
//MARK: Public Instance Methods
//MARK:

extension CameraPickerViewController {
    @objc public func addPickerItem(_ pickerItem: PickerItem) {
        if self.isViewLoaded {
            self.pickerView.pickerItems.insert(pickerItem, at: 0);
        } else {
            self.addedPickerItems.insert(pickerItem, at: 0)
        }
    }
}

//MARK:
//MARK: Super overrides
//MARK:

extension CameraPickerViewController {
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        weak var weakSelf = self
        
        let cameraPickerItem = PickerItem.cameraPickerItem {
            let cameraPicker = UIImagePickerController()
            cameraPicker.sourceType = UIImagePickerController.SourceType.camera
            cameraPicker.cameraCaptureMode = .photo
            cameraPicker.delegate = weakSelf
            
            weakSelf?.present(cameraPicker, animated: true, completion: nil)
        }
        
        let photoPickerItem = PickerItem.photoLibraryPickerItem {
            let cameraPicker = UIImagePickerController()
            cameraPicker.sourceType = UIImagePickerController.SourceType.photoLibrary
            cameraPicker.delegate = weakSelf
            
            weakSelf?.present(cameraPicker, animated: true, completion: nil)
        }
        
        self.pickerView.pickerItems.append(contentsOf: [cameraPickerItem, photoPickerItem])
        self.pickerView.pickerItems.insert(contentsOf: self.addedPickerItems, at: 0)
        self.pickerView.imageSelectionHandler = {(image: UIImage?) in
            if let imageHandler = weakSelf?.imageSelectionHandler {
                weakSelf?.presentingViewController?.dismiss(animated: true, completion: {
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
    
    override public func viewWillLayoutSubviews() {
        if !isTransitioning {
            let pickerHeight: CGFloat = 253.0
            let pickerFrame = CGRect(x: 0.0,
                                     y: self.view.frame.size.height - pickerHeight,
                                     width: self.view.frame.size.width,
                                     height: pickerHeight)
            self.pickerView.frame = pickerFrame
            let orientation = UIApplication.shared.statusBarOrientation
            let isPortrait = orientation.isPortrait
            
            self.pickerView.orientation = isPortrait ? .portrait : .landscape
            
            let dismissFrame = CGRect(x: CGFloat(0.0),
                                      y: CGFloat(0.0),
                                      width: self.view.frame.size.width,
                                      height: self.view.frame.size.height - self.pickerView.frame.size.height)
            self.dismissView.frame = dismissFrame
        }
        
        super.viewWillLayoutSubviews()
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.hasDoneInitialLayout == false, self.view.window != nil, self.pickerView.window != nil {
            self.hasDoneInitialLayout = true
            self.pickerView.scrollToCamera()
        }
    }
}

//MARK:
//MARK: UIViewControllerTransitioningDelegate
//MARK:

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

//MARK:
//MARK: UIViewControllerAnimatedTransitioning
//MARK:

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
        self.view.frame = containerView.bounds
        
        var dismissStartOpacity: CGFloat = 0.0
        var dismissEndOpacity: CGFloat = 1.0
        var dismissStartRect = self.view.bounds
        var dismissEndRect = CGRect(x: CGFloat(0.0),
                                    y: CGFloat(0.0),
                                    width: self.view.frame.size.width,
                                    height: self.view.frame.size.height - self.pickerView.frame.size.height)
        
        var pickerStartTranslation = CGAffineTransform.init(translationX: CGFloat(0.0), y: self.pickerView.frame.size.height)
        var pickerEndTranslation = CGAffineTransform.identity
        
        var presentingVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
        var tintAdjustmentMode = UIView.TintAdjustmentMode.automatic
        
        if self.isPresenting {
            self.pickerView.scrollToCamera()
            containerView.addSubview(self.view)
            presentingVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
            tintAdjustmentMode = .dimmed
        }
        
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
            
            presentingVC!.view.tintAdjustmentMode = tintAdjustmentMode
        }) { (wasCancelled: Bool) in
            if !self.isPresenting {
                self.view.removeFromSuperview()
            }
            
            self.isTransitioning = false
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

//MARK:
//MARK: UIImagePickerControllerDelegate
//MARK:

extension CameraPickerViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        
        if image == nil {
            image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        }
        
        weak var weakSelf = self
        
        picker.presentingViewController?.dismiss(animated: true) {
            if let vc = weakSelf?.presentingViewController {
                vc.dismiss(animated: true, completion: {
                    if let imageHandler = self.imageSelectionHandler {
                        imageHandler(image)
                    }
                })
            } else {
                print("Uh oh!")
            }
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
