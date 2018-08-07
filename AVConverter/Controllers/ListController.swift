//
//  ListController.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit

class ListController: UITableViewController {
    var recordingsManager = RecordingsManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(recordedAudioInserted(_:)), name: .recordedAudioSaved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(exportSuccess(_:)), name: .exportSuccess, object: nil)
        
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
        let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(defaultAction)
        self.present(alertController, animated: true, completion: nil)
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
        cell.textLabel?.text = recordingsManager.getFile(atIndex: indexPath.row).title
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

//    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
//        if editingStyle == .delete {
//            recordingsManager.deleteFile(atIndex: indexPath.row)
//            tableView.deleteRows(at: [indexPath], with: .fade)
//        }
//
//        if editingStyle == .delete {
//            recordingsManager.deleteFile(atIndex: indexPath.row)
//            tableView.deleteRows(at: [indexPath], with: .fade)
//        }
//    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
            self.recordingsManager.deleteFile(atIndex: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
        
        let export = UITableViewRowAction(style: .normal, title: "Export") { (action, indexPath) in
            let audio = self.recordingsManager.getFile(atIndex: indexPath.row)
            VideoCreator.shared.exportMovieFrom(name: audio)
        }
        
        export.backgroundColor = UIColor.blue
        
        return [delete, export]
    }
}
