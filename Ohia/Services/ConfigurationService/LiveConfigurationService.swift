//
//  LiveConfigurationService.swift
//  Ohia
//
//  Created by iain on 12/10/2023.
//

import Foundation

final class LiveConfigurationService: ConfigurationService {
    func string(for key: ConfigurationKey) -> String? {
        return UserDefaults.standard.string(forKey: key.rawValue)
    }
    
    func set(_ value: String?, for key:ConfigurationKey) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }

    func bool(for key: ConfigurationKey) -> Bool {
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }

    func int(for key: ConfigurationKey) -> Int {
        return UserDefaults.standard.integer(forKey: key.rawValue)
    }
    
    func set(_ value: Bool, for key:ConfigurationKey) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }
    
    func set(_ value: Int, for key: ConfigurationKey) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }
}
