//
//  PlaybackViewController.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit
import AVFoundation

class PlaybackViewController: UIViewController
{
    var audioFile: AVAudioFile!
    var recordedAudio: Audio!
    var isQueued: Bool = false

    var audioEngine = AVAudioEngine()
    var changePitchEffect = AVAudioUnitTimePitch()
    var audioPlayerNode = AVAudioPlayerNode()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = recordedAudio.title

        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        navigationItem.leftItemsSupplementBackButton = true

        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try! audioFile = AVAudioFile(forReading: recordedAudio.url as URL)

        setupAudioEngine()
        rewindAction(self)
    }

    override func didMove(toParentViewController parent: UIViewController?) {
        if parent == nil {
            //"Back pressed"
            audioPlayerNode.stop()
        }
    }
    
    override func didReceiveMemoryWarning() {
        audioPlayerNode.stop()
        audioEngine.stop()
    }

    func setupAudioEngine() {
        audioEngine.attach(audioPlayerNode)
        audioEngine.attach(changePitchEffect)
        audioEngine.connect(audioPlayerNode, to: changePitchEffect, format: nil)
        audioEngine.connect(changePitchEffect, to: audioEngine.outputNode, format: nil)
        try! audioEngine.start()
    }
   
    @IBAction func pauseAction(_ sender: AnyObject) {
        audioPlayerNode.pause()
    }
    
    @IBAction func playAction(_ sender: AnyObject) {
        if !isQueued {
            rewindAction(self)
        }
        audioPlayerNode.play()
    }
    
    func rewindAction(_ sender: AnyObject) {
        audioPlayerNode.stop()
        audioPlayerNode.reset()
        
        isQueued = true
        audioPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: {
            self.isQueued = false
        })
    }
}
