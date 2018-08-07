//
//  RecordingsManager.swift
//  AVConverter
//
//  Created by Utsav Patel on 7/31/18.
//  Copyright © 2018 erbittuu. All rights reserved.
//

import Foundation

class RecordingsManager {
 
    var dirPath: String {
        return FileManager.documentDirectory
    }

    var fileList: [String]! {
        let manager = FileManager.default
        let files = try! manager.contentsOfDirectory(atPath: dirPath)
        return files.sorted { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedDescending }
    }

    var count: Int {
        get {
           return fileList.count
        }
    }

    func getFile(atIndex index: Int) -> Audio {
        let basePath = FileManager.urlFor(name: fileList[index]) // URL(string: "\(dirPath)/\(fileList[index])")
        let title = fileList[index]
        
        var count = 0
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(atPath: basePath.relativePath)
 
            let allMax = fileURLs.map {
                return Int($0.replacingOccurrences(of: "frame_", with: "").replacingOccurrences(of: ".png", with: "")) ?? 0
                }.max() ?? 0
            
            count = allMax
            // process files
        } catch {
            print("Error while enumerating files \(basePath.path): \(error.localizedDescription)")
        }
        
        return Audio(basePath: basePath.absoluteString, name: title, audio: basePath.appendingPathComponent("audio.m4a") , title: title, frameCountMax: count)
    }

    func deleteFile(atIndex index: Int) {
        let filePath = FileManager.urlFor(name: fileList[index])
        try! FileManager.default.removeItem(at: filePath)
    }
}

extension FileManager {
    
    static var documentDirectory: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    private static var documentDirectory1: URL {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }
    
    static func urlFor(name: String) -> URL {
        return documentDirectory1.appendingPathComponent(name)
    }
}
