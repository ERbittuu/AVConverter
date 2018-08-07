//
//  Audio.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import Foundation

struct Audio {
    let basePath: String
    let name: String
    let audio: URL
    let title: String
    
    let frameCountMax: Int
    
    func videoAvailable() -> Bool {
        let url = URL(string: basePath)!
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("finalVideo.mp4").relativePath)
    }
}
