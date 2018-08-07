//
//  PlaybackViewController.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit
import AVFoundation

class PlaybackController: UIViewController {
    
    var recordedAudio: Audio!
    @IBOutlet weak var waveView: WaveView!
    @IBOutlet weak var recordLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = recordedAudio.title
        Recording.default.delegate = self
        
        if !Recording.default.use(url: recordedAudio.audio) {
            print("Something is ongoing...")
        }
    }

    override func didMove(toParentViewController parent: UIViewController?) {
        if parent == nil {
            if Recording.default.state == .Play {
                Recording.default.stop()
                print("Playing Stop")
            }
        }
    }
    
    @IBAction func tapWaveform(_ sender: UITapGestureRecognizer) {
        if Recording.default.state == .Play {
            Recording.default.stop()
            print("Playing Stop")
        } else {
            do {
                try Recording.default.play()
                print("Playing...")
                waveView.waveColor = UIColor.activeWaveColor
            } catch (let error) {
                print("Error in Playing:" + error.localizedDescription)
            }
            recordLabel.text = "Tap to Stop"
        }
    }
}

extension PlaybackController: RecorderDelegate {
    func audioMeterDidUpdate(dB: Float) {
        waveView.updateWithLevel(CGFloat(dB))
    }
}
