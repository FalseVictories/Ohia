//
//  OhiaItem.swift
//  Ohia
//
//  Created by iain on 25/10/2023.
//

import BCKit
import Foundation
import SwiftUI
import OSLog

struct OhiaTrack {
    let title: String
    let artist: String
    let trackNumber: Int
    let duration: Double
    let file: URL

    init(title: String,
         artist: String,
         trackNumber: Int,
         duration: Double,
         file: URL) {
        self.title = title
        self.artist = artist
        self.trackNumber = trackNumber
        self.duration = duration
        self.file = file
    }
    
    init(from track: BCTrack) {
        title = track.title
        artist = track.artist
        trackNumber = track.trackNumber
        duration = track.duration
        file = track.file
    }
}

@MainActor
class OhiaItem: ObservableObject, Identifiable {
    enum State: String, CaseIterable, Identifiable{
        case none
        case waiting
        case retrying
        case connecting
        case downloading
        case downloaded
        case maybeDownloaded
        case cancelled
        case failed
        case error
        
        var id: String { return self.rawValue }
    }
    
    let id: Int
    let title: String
    let artist: String
    let added: Int

    let isHidden: Bool
    let isPreorder: Bool

    let downloadUrl: URL
    var thumbnailUrl: URL?
    var downloadUrls: DownloadUrls?
    
    var tracks: [OhiaTrack]
    
    var retryCount: Int = 0
    
    @Published var isNew: Bool
    @Published var thumbnail: Image
    @Published var state: State = .none
    @Published var downloadProgress = ItemDownloadProgress()
    
    var lastError: (any Error)?
    
    init(id: Int,
         title: String,
         artist: String,
         tracks: [OhiaTrack],
         added: Int,
         isPreorder: Bool,
         isHidden: Bool,
         isNew: Bool,
         downloadUrl: URL,
         state: State = .none) {
        self.id = id
        self.title = title
        self.artist = artist
        self.tracks = tracks
        self.added = added
        self.downloadUrl = downloadUrl
        self.thumbnail = Image(.defaultIcon)
        self.state = state
        self.isPreorder = isPreorder
        self.isHidden = isHidden
        self.isNew = isNew
    }

    static func preview(for state: State) -> OhiaItem {
        return OhiaItem(id: 1, title: "Travels in Constants", 
                        artist: "Songs: Ohia",
                        tracks: [],
                        added: 0,
                        isPreorder: false,
                        isHidden: false,
                        isNew: false,
                        downloadUrl: URL(string: "https://example.com")!,
                        state: state)
    }
    
    static func new() -> OhiaItem {
        return OhiaItem(id: 1,
                        title: "Travels in Constants",
                        artist: "Songs: Ohia",
                        tracks: [],
                        added: 0, isPreorder: false,
                        isHidden: false,
                        isNew: true,
                        downloadUrl: URL(string: "https://example.com")!)
    }
}

extension OhiaItem {
    func setThumbnail(image: Image) {
        thumbnail = image
    }
    
    func set(state: State) {
        self.state = state
        if state == .retrying {
            // Give it 5 goes, and then fail
            if retryCount > 5 {
                self.state = .failed
            } else {
                retryCount += 1
            }
        }
    }
    
    func startDownloading() {
        downloadProgress.resetProgress()
        state = .downloading
    }
    
    func setDownloadUrls(_ urls: DownloadUrls) {
        self.downloadUrls = urls
    }
    
    func verifyDownload(in downloadFolder: URL, format: FileFormat) -> Bool {
        let fm = FileManager.default
        
        for track in tracks {
            let filename = "\(track.artist) - \(title) - \(String(format: "%02d", track.trackNumber)) \(track.title).\(format.getExtension())"
            var isDir = ObjCBool(false)
            let fileUrl = downloadFolder.appending(path: filename, directoryHint: .notDirectory)
            
            let filePath = fileUrl.path
            Logger.Item.debug("Checking \(filePath)")
            if !fm.fileExists(atPath: filePath, isDirectory: &isDir) || isDir.boolValue {
                return false
            }
        }
        return true
    }
}
