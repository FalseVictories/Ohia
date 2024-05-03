//
//  BCItem.swift
//  
//
//  Created by iain on 10/10/2023.
//

import Foundation

public struct BCTrack: Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let artist: String
    public let trackNumber: Int
    public let duration: Double
    public let file: URL
}

public struct BCItem: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let artist: String
    public let added: Int
    public let isPreorder: Bool
    public let isHidden: Bool

    public let downloadUrl: URL
    public let thumbnailUrl: URL?
    
    public let tracklist: [BCTrack]
}

public enum FileFormat: String, Sendable {
    case mp3_v0 = "mp3-v0"
    case mp3_320 = "mp3-320"
    case flac = "flac"
    case aachi = "aac-hi"
    case vorbis = "vorbis"
    case alac = "alac"
    case wav = "wav"
    case aiff = "aiff-lossless"
    
    public func getExtension() -> String {
        switch self {
        case .mp3_v0, .mp3_320:
            return "mp3"
        case .flac:
            return "flac"
        case .aachi:
            return "aac"
        case .vorbis:
            return "ogg"
        case .alac:
            return "alac"
        case .wav:
            return "wav"
        case .aiff:
            return "aiff"
        }
    }
}

public struct BCItemDownload: Sendable {
    public let format: FileFormat
    public let url: URL
}

public struct BCCollectionSummary: Sendable {
    public let userId: Int
    public let username: String
    public let homepage: URL?
    public let itemIds: [Int] // TrAlbumId
}
