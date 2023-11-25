//
//  File.swift
//  
//
//  Created by iain on 10/10/2023.
//

import Foundation

public struct BCItem: Identifiable {
    public let id: Int
    public let name: String
    public let artist: String
    public let added: Int
    public let isPreorder: Bool
    public let isHidden: Bool

    public let downloadUrl: URL
    public let thumbnailUrl: URL?
}

public enum FileFormat: String {
    case mp3_v0 = "mp3-v0"
    case mp3_320 = "mp3-320"
    case flac = "flac"
    case aachi = "aac-hi"
    case vorbis = "vorbis"
    case alac = "alac"
    case wav = "wav"
    case aiff = "aiff-lossless"
}

public struct BCItemDownload {
    public let format: FileFormat
    public let url: URL
}

public struct BCCollectionSummary {
    public let userId: Int
    public let username: String
    public let homepage: URL?
    public let itemIds: [Int] // TrAlbumId
}
