//
//  Recording.swift
//  AVConverter
//
//  Created by Utsav Patel on 8/3/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit
import AVFoundation
import QuartzCore

@objc public protocol RecorderDelegate: AVAudioRecorderDelegate {
    @objc optional func audioMeterDidUpdate(dB: Float)
}

public class Recording: NSObject {
    
    @objc public enum State: Int {
        case None, Record, Play
    }
    
    public weak var delegate: RecorderDelegate?
    public private(set) var url: URL!
    public private(set) var state: State = .None
    
    public var bitRate = 192000
    public var sampleRate = 44100.0
    public var channels = 2
    
    private let session = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var link: CADisplayLink?
    
    // MARK: - Initializers
    
    public static let `default` = Recording()
    
    private override init() { }
  
    public func useCreateAudio(name: String) -> Bool {
//        var name = name
//        name = name + ".m4a"
        if self.state != .None {
            return false
        }
        self.url = URL(fileURLWithPath: FileManager.documentDirectory).appendingPathComponent(name)
        return true
    }
    
    public func use(url: URL) -> Bool {
        if self.state != .None {
            return false
        }
        self.url = url
        return true
    }
    
    // MARK: - Record
    
    public func prepare() throws {
        let settings: [String: AnyObject] = [
            AVFormatIDKey : NSNumber(value: kAudioFormatMPEG4AAC),
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue as AnyObject,
            AVEncoderBitRateKey: bitRate as AnyObject,
            AVNumberOfChannelsKey: channels as AnyObject,
            AVSampleRateKey: sampleRate as AnyObject
        ]
        
        do {
            try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        
        recorder = try AVAudioRecorder(url: url.appendingPathComponent("audio.m4a"), settings: settings)
        recorder?.prepareToRecord()
        recorder?.delegate = delegate
        recorder?.isMeteringEnabled = true
    }
    
    public func record() throws {
        if recorder == nil {
            try prepare()
        }
        
        try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
//        try session.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
        
        recorder?.record()
        state = .Record
        
        startMetering()
    }
    
    // MARK: - Playback
    
    public func play() throws {
        try session.setCategory(AVAudioSessionCategoryPlayback)
        
        player = try AVAudioPlayer(contentsOf: url)
        player?.isMeteringEnabled = true
        player?.play()
        startMetering()
        state = .Play
    }
    
    public func stop() {
        switch state {
        case .Play:
            player?.stop()
            player = nil
            stopMetering()
        case .Record:
            recorder?.stop()
            recorder = nil
            stopMetering()
            
//            // Move audio in direcory
//            let fileName = url.lastPathComponent.replacingOccurrences(of: url.pathExtension, with: "")
//            let _url = URL(fileURLWithPath: FileManager.documentDirectory).appendingPathComponent(fileName)
//            
//            do {
//                if FileManager.default.fileExists(atPath: _url.absoluteString) {
//                    try FileManager.default.removeItem(at: _url)
//                }
//                try FileManager.default.createDirectory(atPath: _url.absoluteString, withIntermediateDirectories: false, attributes: nil)
//            } catch let error as NSError {
//                print(error.localizedDescription);
//            }
//            
//            // Move file

            
        default:
            break
        }
        
        state = .None
    }
    
    // MARK: - Metering
    
    @objc func updateMeter() {
        
        if state == .Record {
            guard let recorder = recorder else { return }
            recorder.updateMeters()
            let normalizedValue = pow(10, recorder.averagePower(forChannel: 0) / 20)
            delegate?.audioMeterDidUpdate?(dB: normalizedValue)
        } else if state == .Play {
            guard let player = player else { return }
            player.updateMeters()
            let normalizedValue = pow(10, player.averagePower(forChannel: 0) / 20)
            delegate?.audioMeterDidUpdate?(dB: normalizedValue)
        }
    }
    
    private func startMetering() {
        link = CADisplayLink(target: self, selector: #selector(updateMeter))
        link?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
    }
    
    private func stopMetering() {
        link?.invalidate()
        link = nil
    }
}
