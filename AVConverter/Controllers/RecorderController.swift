//
//  RecorderController.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit
import AVFoundation

extension UIColor {
    static let activeWaveColor = UIColor(red:0.928, green:0.103, blue:0.176, alpha:1)
}

extension Notification.Name {
    static let recordedAudioSaved = Notification.Name("recordedAudio.saved")
    static let exportSuccess = Notification.Name("recordedAudio.export")
}


class RecorderController: UIViewController {
    
    var name: String = String.nameWithTime()
    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var waveView: WaveView!
    
    var done: Bool = false

    @IBAction func tapWaveform(_ sender: UITapGestureRecognizer) {
        if done {
            return
        }
        
        if Recording.default.state == .Record {
            Recording.default.stop()
            waveView.capture = false
            print("Recording saved")
            recordLabel.text = "Recorded.. You can Export it from recording list."
            NotificationCenter.default.post(name: .recordedAudioSaved, object: nil)
            self.done = true
        } else {
            
            if Recording.default.useCreateAudio(name: name) {
                do {
                    try Recording.default.prepare()
                    print("Prepare Succeed")
                } catch (let error) {
                    print("Error in prepare:" + error.localizedDescription)
                }
            } else {
                print("Something is ongoing...")
            }
            
            waveView.imageName = Recording.default.url.relativePath
            do {
                try Recording.default.record()
                waveView.waveColor = UIColor.activeWaveColor
                waveView.capture = true
                print("Start recording...")
            } catch (let error) {
                print("Error in start record:" + error.localizedDescription)
            }
            recordLabel.text = "Tap to Stop"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Recording.default.delegate = self
    }
}

extension RecorderController: RecorderDelegate {
    func audioMeterDidUpdate(dB: Float) {
        waveView.updateWithLevel(CGFloat(dB))
    }
}
