//
//  DataStorageService.swift
//  Ohia
//
//  Created by iain on 22/10/2023.
//

import BCKit
import Dependencies
import Foundation

protocol DataStorageService {
    @MainActor
    func openDataStorage(for username: String) throws
    
    @MainActor
    func closeDataStorage() throws
    
    @MainActor
    func loadItems() throws -> [OhiaItem]
    
    @MainActor
    func addItem(_ item: OhiaItem) throws
    
    @MainActor
    func setItemDownloaded(_ item: OhiaItem) throws
    
    @MainActor
    func setUser(_ user: OhiaUser) throws
    
    @MainActor
    func getUser() throws -> OhiaUser?

    @MainActor
    func getCurrentUsername() throws -> String?

    @MainActor
    func setCurrentUsername(_ username: String) throws

    @MainActor
    func setSummary(_ summary: OhiaCollectionSummary) throws

    @MainActor
    func getSummary() throws -> OhiaCollectionSummary
}

enum DataStorageServiceError: Error {
    case noDatabase(String)
    case noCollection(String)
}

@MainActor
private enum DataStorageServiceKey: DependencyKey {
    static let liveValue: any DataStorageService = LiveDataStorageService()
}

extension DependencyValues {
    var dataStorageService: any DataStorageService {
        get { self[DataStorageServiceKey.self] }
        set { self[DataStorageServiceKey.self] = newValue }
    }
}
