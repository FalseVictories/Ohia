//
//  ConfigurationService.swift
//  Ohia
//
//  Created by iain on 12/10/2023.
//

import BCKit
import Dependencies
import Foundation

public enum ConfigurationKey: String {
    case downloadFolder = "downloadFolder"
    case fileFormat = "fileformat"
    case downloadPreorders = "downloadPreorders"
    case decompressDownloads = "decompressDownloads"
}

protocol ConfigurationService {
    func string(for key: ConfigurationKey) -> String?
    func bool(for key: ConfigurationKey) -> Bool
    func set(_ value: String?, for key: ConfigurationKey)
    func set(_ value: Bool, for key: ConfigurationKey)
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
