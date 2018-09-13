//
//  CameraPickerView.swift
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
import Photos

public typealias PickerItemSelectionHandler = () -> (Void)
public typealias CameraPickerImageSelectionHandler = (UIImage?) -> (Void)

// MARK:
// MARK: PickerItem
// MARK:

@objc public class PickerItem : NSObject {
    let title: String
    let image: UIImage?
    let selectionHandler: PickerItemSelectionHandler

    @objc public init(title: String, image: UIImage?, selectionHandler: @escaping PickerItemSelectionHandler) {
        self.title = title
        self.image = image
        self.selectionHandler = selectionHandler
    }

    convenience public init(title: String, selectionHandler: @escaping PickerItemSelectionHandler) {
        self.init(title: title, image: nil, selectionHandler: selectionHandler)
    }
    
    static public func cameraPickerItem(selectionHandler: @escaping PickerItemSelectionHandler) -> PickerItem {
        let bundle = Bundle.init(for: self)
        let image = UIImage(named: "camera", in: bundle, compatibleWith: nil)

        let title = NSLocalizedString("PICKER_ITEM_CAMERA", tableName: nil, bundle: bundle, value: "", comment: "Camera")
        return PickerItem(title: title, image: image, selectionHandler: selectionHandler)
    }
    
    static public func photoLibraryPickerItem(selectionHandler: @escaping PickerItemSelectionHandler) -> PickerItem {
        let bundle = Bundle.init(for: self)
        let image = UIImage(named: "photoLibrary", in: bundle, compatibleWith: nil)
        let title = NSLocalizedString("PICKER_ITEM_PHOTO_LIBRARY", tableName: nil, bundle: bundle, value: "", comment: "Photo Library")

        return PickerItem(title: title, image: image, selectionHandler: selectionHandler)
    }
}

fileprivate enum CameraPickerSection : Int {
    case pickerItems = 0
    case camera
    case photoLibrary
}

fileprivate enum CameraPickerCellIdentifiers : String {
    case pickerItems
    case camera
    case photoLibrary
}

// MARK:
// MARK: PickerItemCell
// MARK:

fileprivate class PickerItemCell : UICollectionViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var stackView: UIStackView!

    var pickerItem: PickerItem? {
        didSet {
            self.updateUI()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.tintColor = UIColor.black

        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14.0)
        label.numberOfLines = 2

        self.titleLabel = label

        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.backgroundColor = UIColor.clear

        self.imageView = imageView

        self.stackView = UIStackView(arrangedSubviews: [self.imageView, self.titleLabel])
        self.stackView.axis = .vertical

        self.contentView.addSubview(stackView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let margin = CGFloat(15.0)
        let insets = UIEdgeInsetsMake(margin, margin, margin, margin)
        let stackViewRect = UIEdgeInsetsInsetRect(self.bounds, insets)

        self.stackView.frame = stackViewRect
    }

    private func updateUI() {
        self.titleLabel.text = self.pickerItem?.title
        self.imageView.image = self.pickerItem?.image

        self.imageView.isHidden = self.pickerItem?.image == nil
    }
}

// MARK:
// MARK: PhotoCell
// MARK:

fileprivate class PhotoCell : UICollectionViewCell {
    private var imageView: UIImageView!

    fileprivate var asset: PHAsset? {
        didSet {
            self.updateUI()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.imageView = UIImageView(frame: self.bounds)
        self.imageView.clipsToBounds = true
        self.imageView.contentMode = .scaleAspectFill
        
        self.addSubview(self.imageView)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override fileprivate func layoutSubviews() {
        super.layoutSubviews()

        self.imageView.frame = self.bounds
    }

    private func updateUI() {
        if let asset = self.asset {
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            let scale = UIScreen.main.scale
            let imageViewSize = self.imageView.frame.size
            let size = CGSize(width: imageViewSize.width * scale, height: imageViewSize.height * scale)
            let photoId = asset.localIdentifier
            self.imageView.image = nil

            weak var weakSelf = self

            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { result, info in
                guard let strongSelf = weakSelf, let currentLocalId = weakSelf?.asset?.localIdentifier else {
                    return;
                }

                if photoId == currentLocalId { // Check to make sure the user hasn't scrolled onward since getting the result
                    strongSelf.imageView.image = result;
                }
            }
        } else {
            self.imageView.image = nil
        }
    }
}

// MARK:
// MARK: CameraCell
// MARK:

fileprivate class CameraCell : UICollectionViewCell {
    fileprivate let cameraTaker: CameraTakerView
    private let indicatorView: PickerItemIndicatorView
    var indicatorProgress = 1.0 {
        willSet {
            guard newValue != self.indicatorProgress else {
                return
            }
            
            self.setNeedsLayout()
        }

        didSet {
            if self.indicatorProgress > 1.0 {
                self.indicatorProgress = 1.0
            } else if self.indicatorProgress < 0.0 {
                self.indicatorProgress = 0.0
            }
        }
    }
    private let indicatorWidth = 20.0

    override init(frame: CGRect) {
        self.cameraTaker = CameraTakerView(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height))
        self.indicatorView = PickerItemIndicatorView(frame: CGRect(x: 0.0, y: 0.0, width: 20.0, height: frame.height))
        super.init(frame: frame)

        self.contentView.addSubview(self.indicatorView)
        self.contentView.addSubview(self.cameraTaker)
    }

    required init?(coder aDecoder: NSCoder) {
        self.cameraTaker = CameraTakerView(frame: CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0))
        self.indicatorView = PickerItemIndicatorView(frame: CGRect(x: 0.0, y: 0.0, width: 20.0, height: 100.0))
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.cameraTaker.frame = self.bounds

        let indicatorWidth = self.indicatorWidth
        let fullyOpen = -indicatorWidth
        self.indicatorView.frame = CGRect(x:fullyOpen * self.indicatorProgress, y:0.0, width:indicatorWidth, height:Double(self.frame.height))
        self.indicatorView.alpha = CGFloat(self.indicatorProgress)
    }
}

// MARK:
// MARK: PickerItemIndicatorView
// MARK:

/// This view is nothing but the chevron, indicating that there are additional items in front of the camera view
fileprivate class PickerItemIndicatorView : UIView {
    var chevron: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override fileprivate func layoutSubviews() {
        super.layoutSubviews()

        if chevron == nil {
            let bundle = Bundle(for: PickerItemIndicatorView.self)
            chevron = UIImageView(image: UIImage(named: "chevron", in: bundle, compatibleWith: nil)!)

            self.addSubview(chevron)
        }

        self.chevron.center = CGPoint(x: self.frame.width * 0.5, y: self.frame.height * 0.5)
    }
}

// MARK:
/* ------------------------------------------------------------------------------------------------ */
// MARK:

@objc public enum CameraPickerViewOrientation : Int {
    case landscape
    case portrait
}

@objc public enum CameraPickerAppearance : Int {
    case normal = 0
    case dark = 1
}

// MARK:
// MARK: CameraPickerView
// MARK:


/// The root view that contains all of the camera and photo picking items in a single UI
public class CameraPickerView : UIView {
    // MARK: Properties
    public var pickerItems = [PickerItem]() {
        didSet {
            self.collectionView.reloadData()
        }
    }
    public var imageSelectionHandler: CameraPickerImageSelectionHandler?
    public var orientation = CameraPickerViewOrientation.portrait
    public var appearance = CameraPickerAppearance.normal {
        didSet {
            self.backgroundColor = self.appearance == .normal ? self.normalBackgroundColor : self.darkBackgroundColor
        }
    }

    fileprivate var collectionView: UICollectionView!
    fileprivate var photos = PHFetchResult<PHAsset>()
    weak fileprivate var cameraTakerView: CameraTakerView?
    weak fileprivate var cameraCell: CameraCell?

    private var isCameraAvailable = false
    private var photoSize = CGSize(width: 200.0, height: 200.0)
    private var hasPerformedInitialOffset = false
    private let normalBackgroundColor = UIColor.init(white: 0.8, alpha: 1.0)
    private let darkBackgroundColor = UIColor.init(white: 0.2, alpha: 1.0);

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.commonInit()
    }
    
    deinit {
        print("CameraPickerView destroyed")
    }

    // MARK: Super Overrides
    override public func layoutSubviews() {
        super.layoutSubviews()

        if (self.collectionView.frame.size != self.bounds.size) {
            self.collectionView.collectionViewLayout.invalidateLayout()
        }

        self.collectionView.frame = self.bounds

        if !self.hasPerformedInitialOffset {
            self.hasPerformedInitialOffset = true

            if self.isCameraAccessible() {
                let section = CameraPickerSection.camera.rawValue
                let cameraIndexPath = IndexPath(item: 0, section: section)
                self.collectionView.scrollToItem(at: cameraIndexPath, at: .left, animated: false)

                var offset = self.collectionView.contentOffset
                let indicatorWidth: CGFloat = 20.0
                let margin: CGFloat = 2.0
                offset = CGPoint(x: offset.x - margin - indicatorWidth , y: offset.y)

                self.collectionView.contentOffset = offset
            }
        }
    }

    override public func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        if newWindow != nil {
            self.requestCameraAccessIfNeeded()
            self.requestPhotoLibraryAccessIfNeeded()
        }
    }

    // MARK: Public Methods
    public func requestCameraAccessIfNeeded() {
        if !self.isCameraAccessible() {
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (grantedAccess: Bool) in
                print("granted access: \(grantedAccess)")
            })
        }
    }
    
    public func requestPhotoLibraryAccessIfNeeded() {
        weak var weakSelf = self
        
        if !self.isPhotoLibraryAccessible() {
            PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) in
                if status == .authorized {
                    weakSelf?.refreshPhotos()
                }
            })
        } else {
            self.refreshPhotos()
        }
    }

    // MARK: Private Methods
    private func commonInit() {
        self.backgroundColor = self.appearance == .normal ? self.normalBackgroundColor : self.darkBackgroundColor
        self.registerCells()
        self.isCameraAvailable = self.isCameraAccessible()

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        PHPhotoLibrary.shared().register(self)
    }
    
    fileprivate func isCameraAccessible() -> Bool {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)

            return status == .authorized
        } else {
            return false
        }
    }

    fileprivate func isPhotoLibraryAccessible() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        return status == .authorized
    }

    fileprivate func registerCells() {
        if self.collectionView == nil {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal

            self.collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: layout)
            self.collectionView.backgroundColor = UIColor.clear
            self.collectionView.dataSource = self
            self.collectionView.delegate = self
            self.collectionView.alwaysBounceHorizontal = true
            self.collectionView.showsHorizontalScrollIndicator = false

            self.addSubview(self.collectionView)
            self.collectionView.frame = self.bounds
        }

        self.collectionView.register(PickerItemCell.self, forCellWithReuseIdentifier: CameraPickerCellIdentifiers.pickerItems.rawValue)
        self.collectionView.register(CameraCell.self, forCellWithReuseIdentifier: CameraPickerCellIdentifiers.camera.rawValue)
        self.collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: CameraPickerCellIdentifiers.photoLibrary.rawValue)
        self.collectionView.register(PickerItemIndicatorView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: CameraPickerCellIdentifiers.camera.rawValue)
        self.collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: CameraPickerCellIdentifiers.pickerItems.rawValue)
    }
    
    @objc func applicationDidBecomeActive() {
        let isCameraAvailable = self.isCameraAccessible()

        if isCameraAvailable != self.isCameraAvailable {
            self.isCameraAvailable = isCameraAvailable

            let indexSet = IndexSet([CameraPickerSection.camera.rawValue])
            self.collectionView.reloadSections(indexSet)
        }
    }
    
    private func refreshPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 40

        DispatchQueue.main.async {
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            self.photos = fetchResult
            self.collectionView.reloadData()
        }
    }
}

/* ------------------------------------------------------------------------------------------------ */

// MARK:
// MARK: UICollectionViewDelegate
// MARK:

extension CameraPickerView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let pickerSection = CameraPickerSection.init(rawValue: indexPath.section)!

        switch pickerSection {
        case .pickerItems:
            let pickerItem = self.pickerItems[indexPath.item]
            pickerItem.selectionHandler()
        case .camera:
            break
        case .photoLibrary:
            if let selectionHandler = self.imageSelectionHandler {
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                let size = PHImageManagerMaximumSize
                let asset = self.photos[indexPath.item]

                PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .default, options: options) { result, info in
                    if result != nil {
                        selectionHandler(result!)
                    }
                }
            }
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let cameraCell = self.cameraCell {
            let xOffset = Double(scrollView.contentOffset.x)
            let cameraOrigin = Double(cameraCell.frame.origin.x)

            var progress = 0.0

            if xOffset < cameraOrigin {
                progress = xOffset / cameraOrigin
            } else if cameraCell.indicatorProgress > 1.0 {
                progress = 1.0
            } else {
                progress = 0.0
            }
            
            if (progress < 0.0) {
                progress = 0.0
            }

            cameraCell.indicatorProgress = progress
        }
    }

}

/* ------------------------------------------------------------------------------------------------ */

// MARK:
// MARK: UICollectionViewDataSource
// MARK:

extension CameraPickerView : UICollectionViewDataSource {
 
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return CameraPickerSection.photoLibrary.rawValue + 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let pickerSection = CameraPickerSection.init(rawValue: section) else {
            return 0
        }
        
        switch pickerSection {
        case .pickerItems:
            return self.pickerItems.count
        case .camera:
            return self.isCameraAccessible() ? 1 : 0
        case .photoLibrary:
            guard self.isPhotoLibraryAccessible() else {
                return 0
            }

            return photos.count
        }
        
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let pickerSection = CameraPickerSection.init(rawValue: indexPath.section)!

        switch pickerSection {
        case .pickerItems:
            let pickerItemCell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraPickerCellIdentifiers.pickerItems.rawValue, for: indexPath) as! PickerItemCell
            pickerItemCell.pickerItem = self.pickerItems[indexPath.item]
            pickerItemCell.backgroundColor = self.appearance == .normal ? UIColor.white : UIColor.lightGray
            pickerItemCell.layer.cornerRadius = 10.0
            pickerItemCell.clipsToBounds = true

            return pickerItemCell
        case .camera:
            weak var weakSelf = self
            
            let cameraCell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraPickerCellIdentifiers.camera.rawValue, for: indexPath) as! CameraCell
            cameraCell.cameraTaker.captureHandler = {(image: UIImage?, error: Error?) in
                if let handler = weakSelf?.imageSelectionHandler {
                    handler(image)
                }
            }
            cameraCell.tintColor = self.appearance == .normal ? UIColor.darkGray : UIColor.lightGray

            self.cameraCell = cameraCell
            self.cameraTakerView = cameraCell.cameraTaker

            return cameraCell
        case .photoLibrary:
            let photoCell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraPickerCellIdentifiers.photoLibrary.rawValue, for: indexPath) as! PhotoCell
            photoCell.asset = self.photos[indexPath.item]

            return photoCell
        }
    }
}

/* ------------------------------------------------------------------------------------------------ */

// MARK:
// MARK: UICollectionViewDelegateFlowLayout
// MARK:

extension CameraPickerView : UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let pickerSection = CameraPickerSection.init(rawValue: indexPath.section)!
        
        let insets = self.collectionView(collectionView, layout: self.collectionView.collectionViewLayout, insetForSectionAt: indexPath.section)
        
        let cvHeight = floor(Double(collectionView.frame.size.height))

        let itemSpacing = Double(self.collectionView(collectionView, layout: collectionView.collectionViewLayout, minimumInteritemSpacingForSectionAt: indexPath.section))
        let lineSpacing = Double(self.collectionView(collectionView, layout: collectionView.collectionViewLayout, minimumLineSpacingForSectionAt: indexPath.section))

        switch pickerSection {
        case .pickerItems:
            let combinedInsets = Double(insets.top) + Double(insets.bottom)
            let computedHeight = floor((cvHeight - combinedInsets - itemSpacing) * 0.5)
            let ratio = 1.25
            let computedWidth = computedHeight * ratio

            return CGSize(width: computedWidth, height: computedHeight)
        case .photoLibrary:
            let itemSpacing = itemSpacing * 2.0
            
            let combinedInsets = Double(insets.top) + Double(insets.bottom)
            let computedHeight = floor((cvHeight - combinedInsets - itemSpacing - lineSpacing) * 0.5)

            return CGSize(width: computedHeight, height: computedHeight)
        case .camera:
            let contentInsets = collectionView.contentInset
            let combinedInsets = Double(insets.top) + Double(insets.bottom) + Double(contentInsets.top) + Double(contentInsets.bottom)
            let computedHeight = floor(cvHeight - combinedInsets - Double(itemSpacing) - lineSpacing)
            var ratio = 0.820 // Our sensible, magic number default

            let isPortrait = self.orientation == .portrait

            if let cameraTakerView = self.cameraTakerView {
                let intrinsicSize = cameraTakerView.intrinsicContentSize

                if isPortrait {
                    ratio = Double(intrinsicSize.height) / Double(intrinsicSize.width)
                } else {
                    ratio = Double(intrinsicSize.width) / Double(intrinsicSize.height)
                }
            } else {
                ratio = isPortrait ? ratio : 1.0 / ratio
            }

            let width = ceil(ratio * Double(computedHeight))

            return CGSize(width: width, height: cvHeight - 4.0)
        }
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let pickerSection = CameraPickerSection.init(rawValue: section)!
        
        var inset: CGFloat = 0.0

        switch pickerSection {
        case .pickerItems:
            inset = CGFloat(20.0)
        case .camera, .photoLibrary:
            inset = CGFloat(2.0)
        }

        let insets = UIEdgeInsetsMake(inset, inset, inset, inset)
        return insets
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        let pickerSection = CameraPickerSection.init(rawValue: section)!
        
        switch pickerSection {
        case .pickerItems, .camera:
            let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
            return flowLayout.minimumLineSpacing
        case .photoLibrary:
            return 4.0
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        let pickerSection = CameraPickerSection.init(rawValue: section)!
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        
        switch pickerSection {
        case .pickerItems, .camera:
            return flowLayout.minimumInteritemSpacing
        case .photoLibrary:
            return 0.0
        }
    }
}

/* ------------------------------------------------------------------------------------------------ */

// MARK: 
// MARK: PHPhotoLibraryChangeObserver
// MARK:

extension CameraPickerView : PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {

        weak var weakSelf = self

        if let collectionChanges = changeInstance.changeDetails(for: self.photos) {
            DispatchQueue.main.async(execute: {
                weakSelf?.photos = collectionChanges.fetchResultAfterChanges
                let collectionView = weakSelf!.collectionView!

                if !collectionChanges.hasIncrementalChanges || collectionChanges.hasMoves {
                    collectionView.reloadData()
                } else {
                    let toIndexPaths = {(indexSet: IndexSet, section: Int) -> ([IndexPath]) in
                        var indexPaths = [IndexPath]()

                        for index in indexSet.enumerated() {
                            let indexPath = IndexPath(item: index.element, section: section)
                            indexPaths.append(indexPath)
                        }

                        return indexPaths
                    }

                    let section = CameraPickerSection.photoLibrary.rawValue

                    let batchUpdates = {
                        if let removedIndexes = collectionChanges.removedIndexes, removedIndexes.count > 0 {
                            let indexPaths = toIndexPaths(removedIndexes, section)
                            collectionView.deleteItems(at: indexPaths)
                        }

                        if let insertedIndexes = collectionChanges.insertedIndexes, insertedIndexes.count > 0 {
                            let indexPaths = toIndexPaths(insertedIndexes, section)
                            collectionView.insertItems(at: indexPaths)
                        }
                    }

                    collectionView.performBatchUpdates(batchUpdates, completion: nil)

                    if let changedIndexes = collectionChanges.changedIndexes {
                        if changedIndexes.count > 0 {
                            collectionView.reloadItems(at: toIndexPaths(changedIndexes, section))
                        }
                    }
                }
            })
        } else {
            print("change notification of photos, but there weren't any changes...")
        }
    }
}

/* ------------------------------------------------------------------------------------------------ */
