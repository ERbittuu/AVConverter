//
//  VideoCreator.swift
//  AVConverter
//
//  Created by Utsav Patel on 8/3/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import Foundation
import AVFoundation
import Photos

class VideoCreator {
    private init() {  }
    public static let shared = VideoCreator()
    
    public static var videoSize: CGSize = CGSize.zero
    public static var fps: Int32 = 30
    
    func accessGranted(completion: @escaping ((Bool) -> ()))  {
        let status = PHPhotoLibrary.authorizationStatus()
        
        if (status == .authorized) {
            // Access has been granted.
            completion(true)
        }
            
        else if (status == .denied) {
            // Access has been denied.
            completion(false)
        }
            
        else if (status == .notDetermined) {
            
            // Access has not been determined.
            PHPhotoLibrary.requestAuthorization { (_status) in
                if (_status == .authorized) {
                    // Access has been granted.
                    completion(true)
                }
                else {
                    // Access has been denied.
                    completion(false)
                }
            }
        }
            
        else if (status == .restricted) {
            // Restricted access - normally won't happen.
            completion(false)
        }
    }
    
    func exportMovieFrom(name: Audio) {
        
        if name.videoAvailable() {
            
            let url = URL(string: name.basePath)!
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url.appendingPathComponent("finalVideo.mp4"))
            }) { saved, error in
                if saved {
                    NotificationCenter.default.post(name: .exportSuccess, object: nil)
                }
            }
            
            return
        }
        
        print("Export Clicked")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        print("Start Exporting...")
            
        let videoURL = URL(string: name.basePath)?.appendingPathComponent("video.mp4")
            self.writeImagesAsMovie(audio: name, videoURL: videoURL!, videoFPS: VideoCreator.fps)
        }
    }
    
    func writeImagesAsMovie(audio: Audio, videoURL: URL, videoFPS: Int32) {
        
        let url = URL(string: audio.basePath)!
        
        let _urlx = url.appendingPathComponent("/frame_0.png")
        let imgTemp = UIImage(contentsOfFile: _urlx.relativePath)!
        
        let videoSize: CGSize = imgTemp.size
        
        
        let audioAsset = AVAsset(url: audio.audio)
        let time = audioAsset.duration
        var videoFPS = Float64(videoFPS)
        videoFPS = Float64(audio.frameCountMax) / CMTimeGetSeconds(time)
        
        // Create AVAssetWriter to write video
        guard let assetWriter = createAssetWriter(url: videoURL, size: videoSize) else {
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
        let frameDuration = CMTimeMake(1, Int32(videoFPS))
        var frameCount = 0
    
        // -- Add images to video
        let numImages = audio.frameCountMax
        
//            ?.appendingPathComponent("video.mp4")
//        NSString* filename = [NSString stringWithFormat:@"/frame_%d.png", index];

        writerInput.requestMediaDataWhenReady(on: mediaQueue, using: { () -> Void in
            // Append unadded images to video but only while input ready
            while writerInput.isReadyForMoreMediaData && frameCount < numImages {
                let lastFrameTime = CMTimeMake(Int64(frameCount), Int32(videoFPS))
                let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                let _url = url.appendingPathComponent("/frame_\(frameCount).png")
                let img = UIImage(contentsOfFile: _url.relativePath)!
                if !self.appendPixelBufferForImageAtURL(image: img, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
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
                        self.addVideoAndAudio(videoURL: videoURL, and: audio.audio, file: audio)
                        print("Converted images to movie @ \(videoURL)")
                    }
                }
            }
        })
    }

    // MARK: - Create Asset Writer -
    func createAssetWriter(url: URL, size: CGSize) -> AVAssetWriter? {
        // Convert <path> to NSURL object
        let pathURL = url

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
//
//    // MARK: - Append Pixel Buffer -
//
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
//
//    // MARK: - Fill Pixel Buffer -
//
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
//
//    // MARK: - Save Video -
//
    func addVideoAndAudio(videoURL: URL,and audioURL : URL, file: Audio) {

        let videoAsset = AVAsset(url: videoURL)
        let audioAsset = AVAsset(url: audioURL)

        KVVideoManager.shared.merge(video: videoAsset, withBackgroundMusic: audioAsset, file: file) { (url, error) in
            print("-- - - - - -- -- - --  - --- - -- - --  - -  -- - - -")
            print(url ?? error ?? "both")
            if let _url = url {
                
                let url = URL(string: file.basePath)!
                let _urlVideoTemp = url.appendingPathComponent("video.mp4")
                
                let fileManager = FileManager.default
                
                fileManager.removeItemIfExisted(_urlVideoTemp)
                
                do {
                    let fileURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)

                    for fileUrl in fileURLs {
                        if fileUrl.pathExtension == "png" {
                            fileManager.removeItemIfExisted(fileUrl)
                        }
                    }
                } catch { }
                
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: _url)
                }) { saved, error in
                    if saved {
                        NotificationCenter.default.post(name: .exportSuccess, object: nil)
                    }
                }
            }
            print("-- - - - - -- -- - --  - --- - -- - --  - -  -- - - -")
        }
    }
}

import UIKit
import MediaPlayer
import MobileCoreServices
import AVKit

class KVVideoManager: NSObject {
    static let shared = KVVideoManager()

    let defaultSize = CGSize(width: 1920, height: 1080) // Default video size

    typealias Completion = (URL?, Error?) -> Void
    
    //
    // Add background music to video
    //
    func merge(video:AVAsset, withBackgroundMusic music:AVAsset, file: Audio , completion:@escaping Completion) -> Void {
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

        let _url = URL(string: file.basePath)!
        
        let exportURL = _url.appendingPathComponent("finalVideo.mp4")

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

        let fileName = "finalVideo"
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
}
//
//// MARK:- Private methods
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


extension String {
    
    static func nameWithTime() -> String {
        return "\(Date().timeIntervalSince1970)"
    }
}
