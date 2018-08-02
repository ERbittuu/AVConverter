//
//  FilesViewController.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import UIKit

class FilesViewController: UITableViewController {
    var recordingsManager = RecordingsManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(recordedAudioInserted(_:)), name: .recordedAudioSaved, object: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showPlayback") {
            let playbackVC = segue.destination as! PlaybackViewController

            let indexPath = tableView.indexPathForSelectedRow
            let audioFile = recordingsManager.getFile(atIndex: indexPath!.row)
            playbackVC.recordedAudio = audioFile
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
        cell.textLabel?.text = recordingsManager.getFile(atIndex: indexPath.row).title
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            recordingsManager.deleteFile(atIndex: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
