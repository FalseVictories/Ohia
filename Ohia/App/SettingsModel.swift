//
//  SettingsModel.swift
//  Ohia
//
//  Created by iain on 25/10/2023.
//

import BCKit
import Dependencies
import Foundation

@MainActor
final class SettingsModel: ObservableObject {
    @Dependency(\.configurationService) var configService: any ConfigurationService

    @Published var selectedFileFormat: FileFormat = .flac {
        didSet {
            var cs = configService
            cs.fileFormat = selectedFileFormat
        }
    }

    @Published var selectedDownloadFolder: URL? {
        didSet {
            var cs = configService
            cs.downloadFolder = selectedDownloadFolder
        }
    }

    @Published var downloadPreorders: Bool = false {
        didSet {
            var cs = configService
            cs.downloadPreorders = downloadPreorders
        }
    }
}

extension SettingsModel {
    func loadDefaults() {
        selectedFileFormat = configService.fileFormat
        selectedDownloadFolder = configService.downloadFolder
        downloadPreorders = configService.downloadPreorders
    }
}
