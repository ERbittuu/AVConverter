//
//  RecordViewController.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit
import AVFoundation

extension Notification.Name {
    static let recordedAudioSaved = Notification.Name("recordedAudio.saved")
}

class RecordViewController: UIViewController, AVAudioRecorderDelegate
{
    var audioRecorder: AVAudioRecorder!
    var isRecording: Bool = false {
        didSet {
            if isRecording {
                recordLabel.text = "Tap to Stop"
                waveformView.waveColor = UIColor(red:0.928, green:0.103, blue:0.176, alpha:1)
            } else {
                recordLabel.text = "Tap to Record"
                waveformView.waveColor = UIColor.black
            }
        }
    }

    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var waveformView: WaveformView!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        navigationItem.leftItemsSupplementBackButton = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        audioRecorder = audioRecorder(URL(fileURLWithPath:"/dev/null"))
        audioRecorder.record()

        let displayLink = CADisplayLink(target: self, selector: #selector(updateMeters))
        displayLink.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        
        
    }

    @IBAction func tapWaveform(_ sender: UITapGestureRecognizer) {
        if isRecording {
            stopRecordingAudio()
        } else {
            recordAudio()
        }

        isRecording = !isRecording
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showPlayback") {
            let playbackVC = segue.destination as! PlaybackViewController
            playbackVC.recordedAudio = sender as! Audio
        }
    }

    @objc func updateMeters() {
        audioRecorder.updateMeters()
        let normalizedValue = pow(10, audioRecorder.averagePower(forChannel: 0) / 20)
        print(normalizedValue)
        waveformView.updateWithLevel(CGFloat(normalizedValue))
    }

    func recordAudio() {
        audioRecorder.stop()
        audioRecorder = audioRecorder(RecordingsManager.timestampedFilePath())
        audioRecorder.delegate = self
        audioRecorder.record()
        
        waveformView.startRecording()
        waveformView.delegate = self
        
//        let timer : DispatchSourceTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
//
//        timer.schedule(deadline: .now(), repeating: 0.01)
//        timer.setEventHandler {
//            self.waveformView.setNeedsDisplay()
//        }
//        timer.resume()
    }

    func stopRecordingAudio() {
        audioRecorder.stop()
        
        waveformView.stopRecording()

        try! AVAudioSession.sharedInstance().setActive(false)
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
////
//            var images : [UIImage] = []
//            for i in 1 ..< 390 {
//                let filename = "frame_\(i)"
//                let image = UIImage(named: filename)!
//                images.append(image)
//            }
//
//            let fileName = "Test"
//            let DocumentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//            let fileURL = DocumentDirURL.appendingPathComponent(fileName).appendingPathExtension("mov")
//
//            print("File PAth: \(fileURL.path)")
//
//            self.writeImagesAsMovie(allImages: images, videoPath: fileURL.absoluteString , videoSize: CGSize(width: 400, height: 400) , videoFPS: 30)
//        }
    }

    func audioRecorder(_ filePath: URL) -> AVAudioRecorder {
        let recorderSettings: [String : AnyObject] = [
            AVSampleRateKey: 44100.0 as AnyObject,
            AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey: 2 as AnyObject,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue as AnyObject
        ]

        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)

        let audioRecorder = try! AVAudioRecorder(url: filePath, settings: recorderSettings)
        audioRecorder.isMeteringEnabled = true
        audioRecorder.prepareToRecord()

        return audioRecorder
    }

    // MARK: - AVAudioRecorder

    static var audioUrl : URL!
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let recordedAudio = Audio(url: recorder.url, title: recorder.url.lastPathComponent)
        RecordViewController.audioUrl = recorder.url
        NotificationCenter.default.post(name: .recordedAudioSaved, object: nil)
        performSegue(withIdentifier: "showPlayback", sender: recordedAudio)
    }
}

extension RecordViewController : ScreenCaptureViewDelegate {
    func recordingFinished(_ outputPathOrNil: String!) {
        print(outputPathOrNil)
    }
    
    // MARK: - Write Images as Movie -
    
    func writeImagesAsMovie(allImages: [UIImage], videoPath: String, videoSize: CGSize, videoFPS: Int32) {
        // Create AVAssetWriter to write video
        guard let assetWriter = createAssetWriter(path: videoPath, size: videoSize) else {
            print("Error converting images to video: AVAssetWriter not created")
            return
        }
        
        // If here, AVAssetWriter exists so create AVAssetWriterInputPixelBufferAdaptor
        let writerInput = assetWriter.inputs.filter { $0.mediaType == AVMediaType.video }.first!
        let sourceBufferAttributes: [String: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB) as AnyObject,
            kCVPixelBufferWidthKey as String: videoSize.width as AnyObject,
            kCVPixelBufferHeightKey as String: videoSize.height as AnyObject
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        // Start writing session
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: kCMTimeZero)
        if pixelBufferAdaptor.pixelBufferPool == nil {
            print("Error converting images to video: pixelBufferPool nil after starting session")
            return
        }
        
        // -- Create queue for <requestMediaDataWhenReadyOnQueue>
        let mediaQueue = DispatchQueue.init(label: "mediaInputQueue")
        
        // -- Set video parameters
        let frameDuration = CMTimeMake(1, videoFPS)
        var frameCount = 0
        
        // -- Add images to video
        let numImages = allImages.count
        writerInput.requestMediaDataWhenReady(on: mediaQueue, using: { () -> Void in
            // Append unadded images to video but only while input ready
            while writerInput.isReadyForMoreMediaData && frameCount < numImages {
                let lastFrameTime = CMTimeMake(Int64(frameCount), videoFPS)
                let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                
                if !self.appendPixelBufferForImageAtURL(image: allImages[frameCount], pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
                    print("Error converting images to video: AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer")
                    return
                }
                
                frameCount += 1
            }
            
            // No more images to add? End video.
            if frameCount >= numImages {
                writerInput.markAsFinished()
                assetWriter.finishWriting {
                    if assetWriter.error != nil {
                        print("Error converting images to video: \(assetWriter.error?.localizedDescription ?? "")")
                    } else {
                        self.saveVideoToLibrary(videoURL: URL.init(string: videoPath)!)
                        print("Converted images to movie @ \(videoPath)")
                    }
                }
            }
        })
    }
    
    // MARK: - Create Asset Writer -
    
    func createAssetWriter(path: String, size: CGSize) -> AVAssetWriter? {
        // Convert <path> to NSURL object
        let pathURL = URL.init(string: path)!
        
        // Return new asset writer or nil
        do {
            // Create asset writer
            let newWriter = try AVAssetWriter(outputURL: pathURL, fileType: AVFileType.mp4)
            
            // Define settings for video input
            let videoSettings: [String: AnyObject] = [
                AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
                AVVideoWidthKey: size.width as AnyObject,
                AVVideoHeightKey: size.height as AnyObject
            ]
            
            // Add video input to writer
            let assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
            newWriter.add(assetWriterVideoInput)
            
            // Return writer
            print("Created asset writer for \(size.width)x\(size.height) video")
            return newWriter
        } catch {
            print("Error creating asset writer: \(error)")
            return nil
        }
    }
    
    // MARK: - Append Pixel Buffer -
    
    func appendPixelBufferForImageAtURL(image: UIImage, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            if  let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )
                
                if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                    fillPixelBufferFromImage(image: image, pixelBuffer: pixelBuffer)
                    appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    pixelBufferPointer.deinitialize(count: 1)
                } else {
                    NSLog("Error: Failed to allocate pixel buffer from pool")
                }
                
                pixelBufferPointer.deallocate()
            }
        }
        
        return appendSucceeded
    }
    
    // MARK: - Fill Pixel Buffer -
    
    func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create CGBitmapContext
        let context = CGContext(
            data: pixelData,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        // Draw image into context"
        context?.draw(image.cgImage!, in: CGRect.init(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    // MARK: - Save Video -
    
    func saveVideoToLibrary(videoURL: URL) {
        print(videoURL)

        let videoAsset1 = AVAsset(url: videoURL)
        let aAsset2 = AVAsset(url: RecordViewController.audioUrl)
        

        
        KVVideoManager.shared.merge(video: videoAsset1, withBackgroundMusic: aAsset2) { (url, error) in
            print("-- - - - - -- -- - --  - --- - -- - --  - -  -- - - -")
            print(url ?? error ?? "both")
            print("-- - - - - -- -- - --  - --- - -- - --  - -  -- - - -")
        }
//        mergeFilesWithUrl(videoUrl: videoURL, audioUrl: RecordViewController.audioUrl)
    }
    
    func mergeFilesWithUrl(videoUrl:URL, audioUrl:URL)
    {
        let mixComposition : AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack : [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack : [AVMutableCompositionTrack] = []
        let totalVideoCompositionInstruction : AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        
        //start merge
        
        let aVideoAsset : AVAsset = AVAsset.init(url: videoUrl)
        let aAudioAsset : AVAsset = AVAsset.init(url: audioUrl)
        aAudioAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            
            
            print(aAudioAsset.tracks)
        }
        
        return

        
        mutableCompositionVideoTrack.append(mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        mutableCompositionAudioTrack.append(mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        
        let aVideoAssetTrack : AVAssetTrack = aVideoAsset.tracks(withMediaType: AVMediaType.video)[0]
        let aAudioAssetTrack : AVAssetTrack = aAudioAsset.tracks(withMediaType: AVMediaType.audio)[0]
        
        
        
        do{
            try mutableCompositionVideoTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero, aVideoAssetTrack.timeRange.duration), of: aVideoAssetTrack, at: kCMTimeZero)
            
            //In my case my audio file is longer then video file so i took videoAsset duration
            //instead of audioAsset duration
            
            try mutableCompositionAudioTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero, aVideoAssetTrack.timeRange.duration), of: aAudioAssetTrack, at: kCMTimeZero)
            
            //Use this instead above line if your audiofile and video file's playing durations are same
            
            //            try mutableCompositionAudioTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero, aVideoAssetTrack.timeRange.duration), ofTrack: aAudioAssetTrack, atTime: kCMTimeZero)
            
        }catch{
            
        }
        
        totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero,aVideoAssetTrack.timeRange.duration )
        
        let mutableVideoComposition : AVMutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.frameDuration = CMTimeMake(1, 30)
        
        mutableVideoComposition.renderSize = CGSize(width: 1280, height: 720)
        
        //        playerItem = AVPlayerItem(asset: mixComposition)
        //        player = AVPlayer(playerItem: playerItem!)
        //
        //
        //        AVPlayerVC.player = player
        
        
        
        //find your video on this URl
        let savePathUrl : URL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/newVideo.mp4")
        
        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = savePathUrl
        assetExport.shouldOptimizeForNetworkUse = true
        
        assetExport.exportAsynchronously { () -> Void in
            switch assetExport.status {
                
            case AVAssetExportSessionStatus.completed:
                
                //Uncomment this if u want to store your video in asset
                
                //let assetsLib = ALAssetsLibrary()
                //assetsLib.writeVideoAtPathToSavedPhotosAlbum(savePathUrl, completionBlock: nil)
                
                print("success")
            case  AVAssetExportSessionStatus.failed:
                print("failed \(String(describing: assetExport.error))")
            case AVAssetExportSessionStatus.cancelled:
                print("cancelled")
            default:
                print("complete")
            }
        }
        
        
    }
}


//
//  KVVideoManager.swift
//  MergeVideos
//
//  Created by Khoa Vo on 12/20/17.
//  Copyright © 2017 Khoa Vo. All rights reserved.
//

import UIKit
import MediaPlayer
import MobileCoreServices
import AVKit

class VideoData: NSObject {
    var index:Int?
    var image:UIImage?
    var asset:AVAsset?
    var isVideo = false
}

class TextData: NSObject {
    var text = ""
    var fontSize:CGFloat = 40
    var textColor = UIColor.red
    var showTime:CGFloat = 0
    var endTime:CGFloat = 0
    var textFrame = CGRect(x: 0, y: 0, width: 500, height: 500)
}

class KVVideoManager: NSObject {
    static let shared = KVVideoManager()
    
    let defaultSize = CGSize(width: 1920, height: 1080) // Default video size
    var videoDuration = 30.0 // Duration of output video when merging videos & images
    var imageDuration = 5.0 // Duration of each image
    
    
    typealias Completion = (URL?, Error?) -> Void
    
    //
    // Merge array videos
    //
    func merge(arrayVideos:[AVAsset], completion:@escaping Completion) -> Void {
        doMerge(arrayVideos: arrayVideos, animation: false, completion: completion)
    }
    
    //
    // Merge array videos with transition animation
    //
    func mergeWithAnimation(arrayVideos:[AVAsset], completion:@escaping Completion) -> Void {
        doMerge(arrayVideos: arrayVideos, animation: true, completion: completion)
    }
    
    //
    // Add background music to video
    //
    func merge(video:AVAsset, withBackgroundMusic music:AVAsset, completion:@escaping Completion) -> Void {
        // Init composition
        let mixComposition = AVMutableComposition.init()
        
        // Get video track
        guard let videoTrack = video.tracks(withMediaType: AVMediaType.video).first else {
            completion(nil, nil)
            return
        }
        
        let outputSize = videoTrack.naturalSize
        let insertTime = kCMTimeZero
        
        // Get audio track
        var audioTrack:AVAssetTrack?
        if music.tracks(withMediaType: AVMediaType.audio).count > 0 {
            audioTrack = music.tracks(withMediaType: AVMediaType.audio).first
        }
        
        // Init video & audio composition track
        let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                                   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        let startTime = kCMTimeZero
        let duration = video.duration
        
        do {
            // Add video track to video composition at specific time
            try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(startTime, duration),
                                                       of: videoTrack,
                                                       at: insertTime)
            
            // Add audio track to audio composition at specific time
            if let audioTrack = audioTrack {
                try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(startTime, duration),
                                                           of: audioTrack,
                                                           at: insertTime)
            }
        }
        catch {
            print("Load track error")
        }
        
        // Init layer instruction
        let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack!,
                                                                   asset: video,
                                                                   standardSize: outputSize,
                                                                   atTime: insertTime)
        
        // Init main instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(insertTime, duration)
        mainInstruction.layerInstructions = [layerInstruction]
        
        // Init layer composition
        let layerComposition = AVMutableVideoComposition()
        layerComposition.instructions = [mainInstruction]
        layerComposition.frameDuration = CMTimeMake(1, 30)
        layerComposition.renderSize = outputSize
        
        let fileName = "mergedVideo"
        let DocumentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let exportURL = DocumentDirURL.appendingPathComponent(fileName).appendingPathExtension("mp4")
        
        // Check exist and remove old file
        FileManager.default.removeItemIfExisted(exportURL)
        
        // Init exporter
        let exporter = AVAssetExportSession.init(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = exportURL
        exporter?.outputFileType = AVFileType.mp4
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.videoComposition = layerComposition
        
        // Do export
        exporter?.exportAsynchronously(completionHandler: {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter: exporter, videoURL: exportURL, completion: completion)
            }
        })
    }
    
    private func doMerge(arrayVideos:[AVAsset], animation:Bool, completion:@escaping Completion) -> Void {
        var insertTime = kCMTimeZero
        var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []
        var outputSize = CGSize.init(width: 0, height: 0)
        
        // Determine video output size
        for videoAsset in arrayVideos {
            let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video)[0]
            
            let assetInfo = orientationFromTransform(transform: videoTrack.preferredTransform)
            
            var videoSize = videoTrack.naturalSize
            if assetInfo.isPortrait == true {
                videoSize.width = videoTrack.naturalSize.height
                videoSize.height = videoTrack.naturalSize.width
            }
            
            if videoSize.height > outputSize.height {
                outputSize = videoSize
            }
        }
        
        if outputSize.width == 0 || outputSize.height == 0 {
            outputSize = defaultSize
        }
        
        // Silence sound (in case of video has no sound track)
        let silenceURL = Bundle.main.url(forResource: "silence", withExtension: "mp3")
        let silenceAsset = AVAsset(url:silenceURL!)
        let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first
        
        // Init composition
        let mixComposition = AVMutableComposition.init()
        
        for videoAsset in arrayVideos {
            // Get video track
            guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else { continue }
            
            // Get audio track
            var audioTrack:AVAssetTrack?
            if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
                audioTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
            }
            else {
                audioTrack = silenceSoundTrack
            }
            
            // Init video & audio composition track
            let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                       preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            
            let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                                       preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            
            do {
                let startTime = kCMTimeZero
                let duration = videoAsset.duration
                
                // Add video track to video composition at specific time
                try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(startTime, duration),
                                                           of: videoTrack,
                                                           at: insertTime)
                
                // Add audio track to audio composition at specific time
                if let audioTrack = audioTrack {
                    try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(startTime, duration),
                                                               of: audioTrack,
                                                               at: insertTime)
                }
                
                // Add instruction for video track
                let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack!,
                                                                           asset: videoAsset,
                                                                           standardSize: outputSize,
                                                                           atTime: insertTime)
                
                // Hide video track before changing to new track
                let endTime = CMTimeAdd(insertTime, duration)
                
                if animation {
                    let timeScale = videoAsset.duration.timescale
                    let durationAnimation = CMTime.init(seconds: 1, preferredTimescale: timeScale)
                    
                    layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange.init(start: endTime, duration: durationAnimation))
                }
                else {
                    layerInstruction.setOpacity(0, at: endTime)
                }
                
                arrayLayerInstructions.append(layerInstruction)
                
                // Increase the insert time
                insertTime = CMTimeAdd(insertTime, duration)
            }
            catch {
                print("Load track error")
            }
        }
        
        // Main video composition instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
        
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(1, 30)
        mainComposition.renderSize = outputSize
        
        // Export to file
        
        let fileName = "mergedVideo"
        let DocumentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let exportURL = DocumentDirURL.appendingPathComponent(fileName).appendingPathExtension("mp4")
        
        // Remove file if existed
        FileManager.default.removeItemIfExisted(exportURL)
        
        // Init exporter
        let exporter = AVAssetExportSession.init(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = exportURL
        exporter?.outputFileType = AVFileType.mp4
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.videoComposition = mainComposition
        
        // Do export
        exporter?.exportAsynchronously(completionHandler: {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter: exporter, videoURL: exportURL, completion: completion)
            }
        })
        
    }
    
    //
    // Merge videos & images
    //
    func makeVideoFrom(data:[VideoData], textData:[TextData]?, completion:@escaping Completion) -> Void {
        var outputSize = CGSize.init(width: 0, height: 0)
        var insertTime = kCMTimeZero
        var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []
        var arrayLayerImages:[CALayer] = []
        
        // Black background video
        guard let bgVideoURL = Bundle.main.url(forResource: "black", withExtension: "mov") else {
            print("Need black background video !")
            completion(nil,nil)
            return
        }
        
        let bgVideoAsset = AVAsset(url: bgVideoURL)
        let bgVideoTrack = bgVideoAsset.tracks(withMediaType: AVMediaType.video).first
        
        // Silence sound (in case of video has no sound track)
        let silenceURL = Bundle.main.url(forResource: "silence", withExtension: "mp3")
        let silenceAsset = AVAsset(url:silenceURL!)
        let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first
        
        // Init composition
        let mixComposition = AVMutableComposition.init()
        
        // Determine video output
        for videoData in data {
            guard let videoAsset = videoData.asset else { continue }
            
            // Get video track
            guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else { continue }
            
            let assetInfo = orientationFromTransform(transform: videoTrack.preferredTransform)
            
            var videoSize = videoTrack.naturalSize
            if assetInfo.isPortrait == true {
                videoSize.width = videoTrack.naturalSize.height
                videoSize.height = videoTrack.naturalSize.width
            }
            
            if videoSize.height > outputSize.height {
                outputSize = videoSize
            }
        }
        
        if outputSize.width == 0 || outputSize.height == 0 {
            outputSize = defaultSize
        }
        
        // Merge
        for videoData in data {
            if videoData.isVideo {
                guard let videoAsset = videoData.asset else { continue }
                
                // Get video track
                guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else { continue }
                
                // Get audio track
                var audioTrack:AVAssetTrack?
                if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
                    audioTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
                }
                else {
                    audioTrack = silenceSoundTrack
                }
                
                // Init video & audio composition track
                let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                           preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
                
                let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                                           preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
                
                do {
                    let startTime = kCMTimeZero
                    let duration = videoAsset.duration
                    
                    // Add video track to video composition at specific time
                    try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(startTime, duration),
                                                               of: videoTrack,
                                                               at: insertTime)
                    
                    // Add audio track to audio composition at specific time
                    if let audioTrack = audioTrack {
                        try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(startTime, duration),
                                                                   of: audioTrack,
                                                                   at: insertTime)
                    }
                    
                    // Add instruction for video track
                    let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack!,
                                                                               asset: videoAsset,
                                                                               standardSize: outputSize,
                                                                               atTime: insertTime)
                    
                    // Hide video track before changing to new track
                    let endTime = CMTimeAdd(insertTime, duration)
                    let timeScale = videoAsset.duration.timescale
                    let durationAnimation = CMTime.init(seconds: 1, preferredTimescale: timeScale)
                    
                    layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange.init(start: endTime, duration: durationAnimation))
                    
                    arrayLayerInstructions.append(layerInstruction)
                    
                    // Increase the insert time
                    insertTime = CMTimeAdd(insertTime, duration)
                }
                catch {
                    print("Load track error")
                }
            }
            else { // Image
                let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                           preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
                
                let itemDuration = CMTime.init(seconds:imageDuration, preferredTimescale: bgVideoAsset.duration.timescale)
                
                do {
                    try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, itemDuration),
                                                               of: bgVideoTrack!,
                                                               at: insertTime)
                }
                catch {
                    print("Load background track error")
                }
                
                // Create Image layer
                guard let image = videoData.image else { continue }
                
                let imageLayer = CALayer()
                imageLayer.frame = CGRect.init(origin: CGPoint.zero, size: outputSize)
                imageLayer.contents = image.cgImage
                imageLayer.opacity = 0
                imageLayer.contentsGravity = kCAGravityResizeAspectFill
                
                setOrientation(image: image, onLayer: imageLayer, outputSize: outputSize)
                
                // Add Fade in & Fade out animation
                let fadeInAnimation = CABasicAnimation.init(keyPath: "opacity")
                fadeInAnimation.duration = 1
                fadeInAnimation.fromValue = NSNumber(value: 0)
                fadeInAnimation.toValue = NSNumber(value: 1)
                fadeInAnimation.isRemovedOnCompletion = false
                fadeInAnimation.beginTime = insertTime.seconds == 0 ? 0.05: insertTime.seconds
                fadeInAnimation.fillMode = kCAFillModeForwards
                imageLayer.add(fadeInAnimation, forKey: "opacityIN")
                
                let fadeOutAnimation = CABasicAnimation.init(keyPath: "opacity")
                fadeOutAnimation.duration = 1
                fadeOutAnimation.fromValue = NSNumber(value: 1)
                fadeOutAnimation.toValue = NSNumber(value: 0)
                fadeOutAnimation.isRemovedOnCompletion = false
                fadeOutAnimation.beginTime = CMTimeAdd(insertTime, itemDuration).seconds
                fadeOutAnimation.fillMode = kCAFillModeForwards
                imageLayer.add(fadeOutAnimation, forKey: "opacityOUT")
                
                arrayLayerImages.append(imageLayer)
                
                // Increase the insert time
                insertTime = CMTimeAdd(insertTime, itemDuration)
            }
        }
        
        // Main video composition instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
        
        // Init Video layer
        let videoLayer = CALayer()
        videoLayer.frame = CGRect.init(x: 0, y: 0, width: outputSize.width, height: outputSize.height)
        
        let parentlayer = CALayer()
        parentlayer.frame = CGRect.init(x: 0, y: 0, width: outputSize.width, height: outputSize.height)
        
        parentlayer.addSublayer(videoLayer)
        
        // Add Image layers
        for layer in arrayLayerImages {
            parentlayer.addSublayer(layer)
        }
        
        // Add Text layer
        if let textData = textData {
            for aTextData in textData {
                let textLayer = makeTextLayer(string: aTextData.text, fontSize: aTextData.fontSize, textColor: UIColor.green, frame: aTextData.textFrame, showTime: aTextData.showTime, hideTime: aTextData.endTime)
                
                parentlayer.addSublayer(textLayer)
            }
        }
        
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(1, 30)
        mainComposition.renderSize = outputSize
        mainComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentlayer)
        
        // Export to file
        let fileName = "mergedVideo"
        let DocumentDirURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let exportURL = DocumentDirURL.appendingPathComponent(fileName).appendingPathExtension("mp4")
        
        // Remove file if existed
        FileManager.default.removeItemIfExisted(exportURL)
        
        let exporter = AVAssetExportSession.init(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = exportURL
        exporter?.outputFileType = AVFileType.mp4
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.videoComposition = mainComposition
        
        // Do export
        exporter?.exportAsynchronously(completionHandler: {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter: exporter, videoURL: exportURL, completion: completion)
            }
        })
    }
}

// MARK:- Private methods
extension KVVideoManager {
    fileprivate func orientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
        var assetOrientation = UIImageOrientation.up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }
        return (assetOrientation, isPortrait)
    }
    
    fileprivate func videoCompositionInstructionForTrack(track: AVCompositionTrack, asset: AVAsset, standardSize:CGSize, atTime: CMTime) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
        
        let transform = assetTrack.preferredTransform
        let assetInfo = orientationFromTransform(transform: transform)
        
        var aspectFillRatio:CGFloat = 1
        if assetTrack.naturalSize.height < assetTrack.naturalSize.width {
            aspectFillRatio = standardSize.height / assetTrack.naturalSize.height
        }
        else {
            aspectFillRatio = standardSize.width / assetTrack.naturalSize.width
        }
        
        if assetInfo.isPortrait {
            let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)
            
            let posX = standardSize.width/2 - (assetTrack.naturalSize.height * aspectFillRatio)/2
            let posY = standardSize.height/2 - (assetTrack.naturalSize.width * aspectFillRatio)/2
            let moveFactor = CGAffineTransform(translationX: posX, y: posY)
            
            instruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveFactor), at: atTime)
            
        } else {
            let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)
            
            let posX = standardSize.width/2 - (assetTrack.naturalSize.width * aspectFillRatio)/2
            let posY = standardSize.height/2 - (assetTrack.naturalSize.height * aspectFillRatio)/2
            let moveFactor = CGAffineTransform(translationX: posX, y: posY)
            
            var concat = assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveFactor)
            
            if assetInfo.orientation == .down {
                let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                concat = fixUpsideDown.concatenating(scaleFactor).concatenating(moveFactor)
            }
            
            instruction.setTransform(concat, at: atTime)
        }
        return instruction
    }
    
    fileprivate func setOrientation(image:UIImage?, onLayer:CALayer, outputSize:CGSize) -> Void {
        guard let image = image else { return }
        
        if image.imageOrientation == UIImageOrientation.up {
            // Do nothing
        }
        else if image.imageOrientation == UIImageOrientation.left {
            let rotate = CGAffineTransform(rotationAngle: .pi/2)
            onLayer.setAffineTransform(rotate)
        }
        else if image.imageOrientation == UIImageOrientation.down {
            let rotate = CGAffineTransform(rotationAngle: .pi)
            onLayer.setAffineTransform(rotate)
        }
        else if image.imageOrientation == UIImageOrientation.right {
            let rotate = CGAffineTransform(rotationAngle: -.pi/2)
            onLayer.setAffineTransform(rotate)
        }
    }
    
    fileprivate func exportDidFinish(exporter:AVAssetExportSession?, videoURL:URL, completion:@escaping Completion) -> Void {
        if exporter?.status == AVAssetExportSessionStatus.completed {
            print("Exported file: \(videoURL.absoluteString)")
            completion(videoURL,nil)
        }
        else if exporter?.status == AVAssetExportSessionStatus.failed {
            completion(videoURL,exporter?.error)
        }
    }
    
    fileprivate func makeTextLayer(string:String, fontSize:CGFloat, textColor:UIColor, frame:CGRect, showTime:CGFloat, hideTime:CGFloat) -> CXETextLayer {
        let textLayer = CXETextLayer()
        textLayer.string = string
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = textColor.cgColor
        textLayer.alignmentMode = kCAAlignmentCenter
        textLayer.opacity = 0
        textLayer.frame = frame
        
        
        let fadeInAnimation = CABasicAnimation.init(keyPath: "opacity")
        fadeInAnimation.duration = 0.5
        fadeInAnimation.fromValue = NSNumber(value: 0)
        fadeInAnimation.toValue = NSNumber(value: 1)
        fadeInAnimation.isRemovedOnCompletion = false
        fadeInAnimation.beginTime = CFTimeInterval(showTime)
        fadeInAnimation.fillMode = kCAFillModeForwards
        
        textLayer.add(fadeInAnimation, forKey: "textOpacityIN")
        
        if hideTime > 0 {
            let fadeOutAnimation = CABasicAnimation.init(keyPath: "opacity")
            fadeOutAnimation.duration = 1
            fadeOutAnimation.fromValue = NSNumber(value: 1)
            fadeOutAnimation.toValue = NSNumber(value: 0)
            fadeOutAnimation.isRemovedOnCompletion = false
            fadeOutAnimation.beginTime = CFTimeInterval(hideTime)
            fadeOutAnimation.fillMode = kCAFillModeForwards
            
            textLayer.add(fadeOutAnimation, forKey: "textOpacityOUT")
        }
        
        return textLayer
    }
}

class CXETextLayer : CATextLayer {
    
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(layer: aDecoder)
    }
    
    override func draw(in ctx: CGContext) {
        let height = self.bounds.size.height
        let fontSize = self.fontSize
        let yDiff = (height-fontSize)/2 - fontSize/10
        
        ctx.saveGState()
        ctx.translateBy(x: 0.0, y: yDiff)
        super.draw(in: ctx)
        ctx.restoreGState()
    }
}

extension FileManager {
    func removeItemIfExisted(_ url:URL) -> Void {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(atPath: url.path)
            }
            catch {
                print("Failed to delete file")
            }
        }
    }
}
