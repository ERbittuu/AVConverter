//
//  ListController.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ListController: UITableViewController {
    var recordingsManager = RecordingsManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(recordedAudioInserted(_:)), name: .recordedAudioSaved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(exportSuccess(_:)), name: .exportSuccess, object: nil)
        
        switch AVAudioSession.sharedInstance().recordPermission() {
        case AVAudioSessionRecordPermission.granted:
            print("Permission granted")
        case AVAudioSessionRecordPermission.denied:
            print("Pemission denied")
        case AVAudioSessionRecordPermission.undetermined:
            print("Request permission here")
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                // Handle granted
            })
        }
        
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showPlayback") {
            let playbackVC = segue.destination as! PlaybackController

            let indexPath = tableView.indexPathForSelectedRow
            let audioFile = recordingsManager.getFile(atIndex: indexPath!.row)
            playbackVC.recordedAudio = audioFile
        }
    }

    @objc func exportSuccess(_ notification: Notification) {
        
        DispatchQueue.main.async {
            HUD.dismiss()
            let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(defaultAction)
            self.present(alertController, animated: true, completion: nil)
            NotificationCenter.default.post(name: .recordedAudioSaved, object: nil)
        }
    }
    
    @objc func recordedAudioInserted(_ notification: Notification) {
        tableView.reloadData()
    }

    // MARK: - TableView

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordingsManager.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileCell", for: indexPath)
        let audio = recordingsManager.getFile(atIndex: indexPath.row)
        cell.textLabel?.text = "\(audio.title) \(audio.videoAvailable() ? "(Saved)" : "" )"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
            self.recordingsManager.deleteFile(atIndex: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
        
        let export = UITableViewRowAction(style: .normal, title: "Export") { (action, indexPath) in
            
            let audio = self.recordingsManager.getFile(atIndex: indexPath.row)
            
            VideoCreator.shared.accessGranted(completion: { (granted) in
                if granted {
                    
                    if audio.videoAvailable() {
                        let url = URL(string: audio.basePath)!
                        
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url.appendingPathComponent("finalVideo.mp4"))
                        }) { saved, error in
                            if saved {
                                NotificationCenter.default.post(name: .exportSuccess, object: nil)
                            }
                        }
                        return
                    }

                    @discardableResult
                    func saveImage(image: UIImage,url : URL) -> Bool {
                        guard let data = UIImagePNGRepresentation(image) else {
                            return false
                        }

                        do {
                            try data.write(to: url)
                            return true
                        } catch {
                            print(error.localizedDescription)
                            return false
                        }
                    }
                    
                    
                    let alertController = UIAlertController(title: "Export", message: "Do you want to add cover image on video?", preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: "Open photo gallery", style: .default, handler: { (_) in
                        self.getImage(completion: { (image) in
                            
                            HUD.show(text: "Exporting video...")
                            let url = URL(string: audio.basePath)!
                            
                            if audio.frameCountMax > 0 {
                                let _url0 = url.appendingPathComponent("/frame_0.png")
                                let img0 = UIImage(contentsOfFile: _url0.relativePath)!
                                let sizeX = img0.size
                                
                                if audio.frameCountMax > 30 {
                                    
                                    for i in 0 ..< 30 {
                                        let _url = url.appendingPathComponent("/frame_\(i).png")
                                        FileManager.default.removeItemIfExisted(_url)
                                        let newImage = image.resizeImage(targetSize: sizeX)
                                        saveImage(image: newImage, url: _url)
                                    }
                                    
                                }else {
                                    for i in 0 ..< audio.frameCountMax {
                                        let _url = url.appendingPathComponent("/frame_\(i).png")
                                        FileManager.default.removeItemIfExisted(_url)
                                        let newImage = image.resizeImage(targetSize: sizeX)
                                        saveImage(image: newImage, url: _url)
                                    }
                                }
                            }
                            
                            VideoCreator.shared.exportMovieFrom(name: audio)
                        })
                    }))
                    
                    alertController.addAction(UIAlertAction(title: "Direct Export", style: .default, handler: { (_) in
                        HUD.show(text: "Exporting video...")
                        VideoCreator.shared.exportMovieFrom(name: audio)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }else {
                    let alertController = UIAlertController(title: "Please allow photo permission from settings", message: nil, preferredStyle: .alert)
                    let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alertController.addAction(defaultAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            })
            
        }
        
        export.backgroundColor = UIColor.blue
        
        return [delete, export]
    }
    
    let imagePicker = UIImagePickerController()
    var returnClouser: ((UIImage) -> ())? = nil

    func getImage(completion: @escaping ((UIImage) -> ())) {

        imagePicker.delegate = self

        imagePicker.allowsEditing = true
        imagePicker.sourceType = .photoLibrary
        returnClouser = completion
        present(imagePicker, animated: true, completion: nil)
    }
}

extension ListController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - ImagePicker Delegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            returnClouser!(pickedImage)
        }
        
        /*
         
         Swift Dictionary named “info”.
         We have to unpack it from there with a key asking for what media information we want.
         We just want the image, so that is what we ask for.  For reference, the available options are:
         
         UIImagePickerControllerMediaType
         UIImagePickerControllerOriginalImage
         UIImagePickerControllerEditedImage
         UIImagePickerControllerCropRect
         UIImagePickerControllerMediaURL
         UIImagePickerControllerReferenceURL
         UIImagePickerControllerMediaMetadata
         
         */
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion:nil)
    }
}


extension UIImage {
    
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
