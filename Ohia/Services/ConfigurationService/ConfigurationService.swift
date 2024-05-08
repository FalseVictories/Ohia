//
//  ConfigurationService.swift
//  Ohia
//
//  Created by iain on 12/10/2023.
//

import BCKit
import Dependencies
import Foundation

public enum FolderStructure: String, Sendable, CaseIterable {
    case none = "none"
    case single = "single"
    case multi = "multi"
    case bandcamp = "bandcamp"
    
    func dirPath(for item: OhiaItem) -> String? {
        switch self {
        case .bandcamp:
            return "\(item.artist)/\(item.artist) - \(item.title)"

        case .none:
            return nil
            
        case .single:
            return "\(item.artist) - \(item.title)"
            
        case .multi:
            return "\(item.artist)/\(item.title)"
        }
    }
}

public enum ConfigurationKey: String {
    case downloadFolder = "downloadFolder"
    case fileFormat = "fileformat"
    case downloadPreorders = "downloadPreorders"
    case decompressDownloads = "decompressDownloads"
    case folderStructure = "folderStructure"
    case maxDownloads = "maxDownloads"
    case overwrite = "overwrite"
}

protocol ConfigurationService: Sendable {
    func string(for key: ConfigurationKey) -> String?
    func bool(for key: ConfigurationKey) -> Bool
    func int(for key: ConfigurationKey) -> Int
    func set(_ value: String?, for key: ConfigurationKey)
    func set(_ value: Bool, for key: ConfigurationKey)
    func set(_ value: Int, for key: ConfigurationKey)
}

extension ConfigurationService {
    var downloadFolder: URL? {
        set {
            set(newValue?.path(percentEncoded: false), for: .downloadFolder)
        }
        get {
            if let folder = string(for: .downloadFolder) {
                return URL(filePath: folder)
            } else {
                // Default to the user's downloads folder
                return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            }
        }
    }
    
    var fileFormat: FileFormat {
        set {
            set(newValue.rawValue, for: .fileFormat)
        }
        get {
            guard let format = string(for: .fileFormat) else {
                return .flac
            }
            return FileFormat(rawValue: format) ?? .flac
        }
    }
    
    var maxDownloads: Int {
        set {
            set(newValue, for: .maxDownloads)
        }
        get {
            int(for: .maxDownloads)
        }
    }

    var downloadPreorders: Bool {
        set {
            set(newValue, for: .downloadPreorders)
        }
        get {
            bool(for: .downloadPreorders)
        }
    }

    var decompressDownloads: Bool {
        set {
            set(newValue, for: .decompressDownloads)
        }
        get {
            bool(for: .decompressDownloads)
        }
    }
    
    var folderStructure: FolderStructure {
        set {
            set(newValue.rawValue, for: .folderStructure)
        }
        get {
            if let result = string(for: .folderStructure) {
                return .init(rawValue: result) ?? .bandcamp
            }
            return .bandcamp
        }
    }
    
    var overwrite: Bool {
        set {
            set(newValue, for: .overwrite)
        }
        get {
            bool(for: .overwrite)
        }
    }
}

private enum ConfigurationServiceKey: DependencyKey {
    static let liveValue: any ConfigurationService = LiveConfigurationService()
}

extension DependencyValues {
    var configurationService: any ConfigurationService {
        get { self[ConfigurationServiceKey.self] }
        set { self[ConfigurationServiceKey.self] = newValue }
    }
}
