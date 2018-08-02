//
//  SwiftSiriWaveformView.swift
//  Pods
//
//  Created by Alankar Misra on 7/23/15.
//
//  Swift adaption of: https://github.com/stefanceriu/SCSiriWaveformView (interface incompatible)

import UIKit

//open class SwiftSiriWaveformView : ScreenCaptureView {
//    /*
//     * The frequency of the sinus wave. The higher the value, the more sinus wave peaks you will have.
//     * Default: 1.5
//     */
//    @IBInspectable open var frequency:CGFloat = 1.5
//
//    /*
//     * The amplitude that is used when the incoming amplitude is near zero.
//     * Setting a value greater 0 provides a more vivid visualization.
//     * Default: 0.01
//     */
//    @IBInspectable open var idleAmplitude:CGFloat = 0.01
//
//    /*
//     * The phase shift that will be applied with each level setting
//     * Change this to modify the animation speed or direction
//     * Default: -0.15
//     */
//    @IBInspectable open var phaseShift:CGFloat = -0.15
//
//    /*
//     * The lines are joined stepwise, the more dense you draw, the more CPU power is used.
//     * Default: 1
//     */
//    @IBInspectable open var density:CGFloat = 1.0
//
//    /*
//     * Line width used for the prominent wave
//     * Default: 1.5
//     */
//    @IBInspectable open var primaryLineWidth:CGFloat = 1.5
//
//    /*
//     * Line width used for all secondary waves
//     * Default: 0.5
//     */
//    @IBInspectable open var secondaryLineWidth:CGFloat = 0.5
//
//
//    /*
//     * The total number of waves
//     * Default: 6
//     */
//    @IBInspectable open var numberOfWaves:Int = 6
//
//    /*
//     * Color to use when drawing the waves
//     * Default: white
//     */
//    @IBInspectable open var waveColor:UIColor = UIColor.white
//
//
//    /*
//     * The current amplitude.
//     */
//    @IBInspectable open var amplitude:CGFloat = 1.0 {
//        didSet {
//            amplitude = max(amplitude, self.idleAmplitude)
//            print(amplitude)
//            self.setNeedsDisplay()
//        }
//    }
//
//    fileprivate var phase:CGFloat = 0.0
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//    }
//
//    public required init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
//    }
//
//    override open func draw(_ rect: CGRect) {
//        // Convenience function to draw the wave
//        func drawWave(_ index:Int, maxAmplitude:CGFloat, normedAmplitude:CGFloat) {
//            let path = UIBezierPath()
//            let mid = self.bounds.width/2.0
//
//            path.lineWidth = index == 0 ? self.primaryLineWidth : self.secondaryLineWidth
//
//            for x in Swift.stride(from:0, to:self.bounds.width + self.density, by:self.density) {
//                // Parabolic scaling
//                let scaling = -pow(1 / mid * (x - mid), 2) + 1
//                let y = scaling * maxAmplitude * normedAmplitude * sin(CGFloat(2 * Double.pi) * self.frequency * (x / self.bounds.width)  + self.phase) + self.bounds.height/2.0
//                if x == 0 {
//                    path.move(to: CGPoint(x:x, y:y))
//                } else {
//                    path.addLine(to: CGPoint(x:x, y:y))
//                }
//            }
//            path.stroke()
//        }
//
//        let context = UIGraphicsGetCurrentContext()
//        context?.setAllowsAntialiasing(true)
//
//        self.backgroundColor?.set()
//        context?.fill(rect)
//
//        let halfHeight = self.bounds.height / 2.0
//        let maxAmplitude = halfHeight - self.primaryLineWidth
//
//        for i in 0 ..< self.numberOfWaves {
//            let progress = 1.0 - CGFloat(i) / CGFloat(self.numberOfWaves)
//            let normedAmplitude = (1.5 * progress - 0.8) * self.amplitude
//            let multiplier = min(1.0, (progress/3.0*2.0) + (1.0/3.0))
//            self.waveColor.withAlphaComponent(multiplier * self.waveColor.cgColor.alpha).set()
//            drawWave(i, maxAmplitude: maxAmplitude, normedAmplitude: normedAmplitude)
//        }
//        self.phase += self.phaseShift
//
//        super.draw(rect)
//    }
//
//
//}

////
//  WaveformView.swift
//  WaveformView
//
//  Created by Jonathan on 3/14/15.
//  Copyright (c) 2015 Underwood. All rights reserved.
//

import UIKit
import Darwin

let pi = Double.pi

@IBDesignable
public class WaveformView: ScreenCaptureView {
    fileprivate var _phase: CGFloat = 0.0
    fileprivate var _amplitude: CGFloat = 0.3

    @IBInspectable public var waveColor: UIColor = .red
    @IBInspectable public var numberOfWaves = 10
    @IBInspectable public var primaryWaveLineWidth: CGFloat = 3.0
    @IBInspectable public var secondaryWaveLineWidth: CGFloat = 1.0
    @IBInspectable public var idleAmplitude: CGFloat = 0.01
    @IBInspectable public var frequency: CGFloat = 1.25
    @IBInspectable public var density: CGFloat = 5
    @IBInspectable public var phaseShift: CGFloat = -0.15

    @IBInspectable public var amplitude: CGFloat {
        get {
            return _amplitude
        }
    }

    public func updateWithLevel(_ level: CGFloat) {
        _phase += phaseShift
        _amplitude = fmax(level, idleAmplitude)
        setNeedsDisplay()
    }

    override public func draw(_ rect: CGRect) {

        let context = UIGraphicsGetCurrentContext()!
        context.clear(bounds)

        backgroundColor?.set()
        context.fill(rect)

        // Draw multiple sinus waves, with equal phases but altered
        // amplitudes, multiplied by a parable function.
        for waveNumber in 0...numberOfWaves {
            context.setLineWidth((waveNumber == 0 ? primaryWaveLineWidth : secondaryWaveLineWidth))

            let halfHeight = bounds.height / 2.0
            let width = bounds.width
            let mid = width / 2.0

            let maxAmplitude = halfHeight - 4.0 // 4 corresponds to twice the stroke width

            // Progress is a value between 1.0 and -0.5, determined by the current wave idx,
            // which is used to alter the wave's amplitude.
            let progress: CGFloat = 1.0 - CGFloat(waveNumber) / CGFloat(numberOfWaves)
            let normedAmplitude = (1.5 * progress - 0.5) * amplitude

            let multiplier: CGFloat = 1.0
            waveColor.withAlphaComponent(multiplier * waveColor.cgColor.alpha).set()

            var x: CGFloat = 0.0
            while x < width + density {
                // Use a parable to scale the sinus wave, that has its peak in the middle of the view.
                let scaling = -pow(1 / mid * (x - mid), 2) + 1
                let tempCasting: CGFloat = 2.0 * CGFloat(pi) * CGFloat(x / width) * frequency + _phase
                let y = scaling * maxAmplitude * normedAmplitude * CGFloat(sinf(Float(tempCasting))) + halfHeight

                if x == 0 {
                    context.move(to: CGPoint(x: x, y: y))
                } else {
                    context.addLine(to: CGPoint(x: x, y: y))
                }

                x += density
            }

            context.strokePath()
        }

//        super.draw(rect)
    }
}
