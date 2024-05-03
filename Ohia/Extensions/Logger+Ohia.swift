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

// https://forums.developer.apple.com/forums/thread/747816
#if swift(>=6.0)
    #warning("Reevaluate whether this decoration is necessary.")
#endif
    
    nonisolated(unsafe) static let App = Logger(subsystem: subsystem, category: "app")
    nonisolated(unsafe) static let Item = Logger(subsystem: subsystem, category: "item")
    nonisolated(unsafe) static let Settings = Logger(subsystem: subsystem, category: "settings")
    nonisolated(unsafe) static let Download = Logger(subsystem: subsystem, category: "downloads")

    // Services
    nonisolated(unsafe) static let ImageService = Logger(subsystem: subsystem, category: "image service")
    nonisolated(unsafe) static let DownloadService = Logger(subsystem: subsystem, category: "download service")
    nonisolated(unsafe) static let DataStorageService = Logger(subsystem: subsystem, category: "data storage service")
}
