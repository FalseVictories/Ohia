//
//  Logger+BCM.swift
//  Bandcamp Collection Manager
//
//  Created by iain on 02/10/2023.
//

import Foundation
import OSLog

extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier!
    
    static let Main = Logger(subsystem: subsystem, category: "Main")
    static let Cookies = Logger(subsystem: subsystem, category: "Cookies")
    static let Collection = Logger(subsystem: subsystem, category: "Collection")
}
