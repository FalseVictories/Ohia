//
//  OhiaItem.swift
//  Ohia
//
//  Created by iain on 25/10/2023.
//

import Foundation
import SwiftUI

@MainActor
class OhiaItem: ObservableObject, Identifiable {
    enum State: String, CaseIterable, Identifiable{
        case none
        case waiting
        case connecting
        case downloading
        case downloaded
        case cancelled
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
    var localFolder: URL?
    
    @Published var isNew: Bool
    @Published var thumbnail: Image
    @Published var state: State = .none
    @Published var downloadProgress = ItemDownloadProgress()
    
    var lastError: (any Error)?
    
    init(id: Int,
         title: String,
         artist: String,
         added: Int,
         isPreorder: Bool,
         isHidden: Bool,
         isNew: Bool,
         downloadUrl: URL,
         state: State = .none) {
        self.id = id
        self.title = title
        self.artist = artist
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
                        artist: "Songs: Ohia", added: 0,
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
    }
    
    func setLocalFolder(_ url: URL) {
        self.localFolder = url
    }
}
