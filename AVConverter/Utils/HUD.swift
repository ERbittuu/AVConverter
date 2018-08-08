//
//  HUD.swift
//  AVConverter
//
//  Created by Utsav Patel on 8/8/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import Foundation
import UIKit

public extension HUD {
    public class func show(text: String) {
        dismiss()
        instance.registerDeviceOrientationNotification()
        let window = UIWindow()
        window.backgroundColor = UIColor.clear
        let mainView = UIView()
        mainView.layer.cornerRadius = 10
        mainView.backgroundColor = UIColor(red:0, green:0, blue:0, alpha: 0.7)
        
        var headView = UIView()
        
        headView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        (headView as! UIActivityIndicatorView).startAnimating()
        headView.translatesAutoresizingMaskIntoConstraints = false
        mainView.addSubview(headView)
        
        // label
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 13)
        label.textAlignment = NSTextAlignment.center
        label.textColor = UIColor.white
        label.sizeToFit()
        label.translatesAutoresizingMaskIntoConstraints = false
        mainView.addSubview(label)
        
        let height = label.frame.height + 70

        let superFrame = CGRect(x: 0, y: 0, width: label.frame.width + 50, height: height)
        window.frame = superFrame
        mainView.frame = superFrame
        
        // image
        
        mainView.addConstraint( NSLayoutConstraint(item: headView, attribute: .centerY, relatedBy: .equal, toItem: mainView, attribute: .centerY, multiplier: 0.6, constant: 0) )
        mainView.addConstraint( NSLayoutConstraint(item: headView, attribute: .centerX, relatedBy: .equal, toItem: mainView, attribute: .centerX, multiplier: 1.0, constant: 0) )
        mainView.addConstraint( NSLayoutConstraint(item: headView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 36) )
        mainView.addConstraint( NSLayoutConstraint(item: headView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 36) )
    
        // label
        let mainViewMultiplier = 1.5

        mainView.addConstraint( NSLayoutConstraint(item: label, attribute: .centerY, relatedBy: .equal, toItem: mainView, attribute: .centerY, multiplier: CGFloat(mainViewMultiplier), constant: 0) )
        mainView.addConstraint( NSLayoutConstraint(item: label, attribute: .centerX, relatedBy: .equal, toItem: mainView, attribute: .centerX, multiplier: 1.0, constant: 0) )
        mainView.addConstraint( NSLayoutConstraint(item: label, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 90) )
        mainView.addConstraint( NSLayoutConstraint(item: label, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0) )
        
        window.windowLevel = UIWindowLevelAlert
        window.center = getCenter()
        window.isHidden = false
        window.addSubview(mainView)
        windowsTemp.append(window)
    }
    
    public class func dismiss() {
        if let _ = timer {
            timer!.cancel()
            timer = nil
        }
        instance.removeDeviceOrientationNotification()
        windowsTemp.removeAll(keepingCapacity: false)
    }
}

open class HUD: NSObject {
    fileprivate static var windowsTemp = [UIWindow]()
    fileprivate static var timer: DispatchSourceTimer?
    fileprivate static let instance = HUD()
    private struct Cache {
        static var imageOfCheckmark: UIImage?
        static var imageOfCross: UIImage?
        static var imageOfInfo: UIImage?
    }
    
    // center
    fileprivate class func getCenter() -> CGPoint {
        if let rv = UIApplication.shared.keyWindow?.subviews.first {
            if rv.bounds.width > rv.bounds.height {
                return CGPoint(x: rv.bounds.height * 0.5, y: rv.bounds.width * 0.5)
            }
            return rv.center
        }
        return .zero
    }
    
    // register notification
    fileprivate func registerDeviceOrientationNotification() {
        NotificationCenter.default.addObserver(HUD.instance, selector: #selector(HUD.transformWindow(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    // remove notification
    fileprivate func removeDeviceOrientationNotification() {
        NotificationCenter.default.removeObserver(HUD.instance)
    }
    
    // transform
    @objc fileprivate func transformWindow(_ notification: Notification) {
        var rotation: CGFloat = 0
        switch UIDevice.current.orientation {
        case .portrait:
            rotation = 0
        case .portraitUpsideDown:
            rotation = .pi
        case .landscapeLeft:
            rotation = .pi * 0.5
        case .landscapeRight:
            rotation = CGFloat(.pi + (.pi * 0.5))
        default:
            break
        }
        HUD.windowsTemp.forEach {
            $0.center = HUD.getCenter()
            $0.transform = CGAffineTransform(rotationAngle: rotation)
        }
    }
}
