//
//  Logger+Ohia.swift
//  Ohia
//
//  Created by iain on 08/10/2023.
//

import Foundation
import OSLog

extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier!
    
    static let Model = Logger(subsystem: subsystem, category: "model")
    static let Item = Logger(subsystem: subsystem, category: "item")
    static let Settings = Logger(subsystem: subsystem, category: "settings")
    static let Download = Logger(subsystem: subsystem, category: "downloads")

    // Services
    static let ImageService = Logger(subsystem: subsystem, category: "image service")
    static let DownloadService = Logger(subsystem: subsystem, category: "download service")
    static let DataStorageService = Logger(subsystem: subsystem, category: "data storage service")
}
