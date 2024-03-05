//
//  DataStorageService.swift
//  Ohia
//
//  Created by iain on 22/10/2023.
//

import BCKit
import Dependencies
import Foundation
import OSLog

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
    func setItemDownloaded(_ item: OhiaItem, downloaded: Bool) throws
    
    @MainActor
    func setItemDownloadLocation(_ item: OhiaItem, location: String) throws
    
    @MainActor
    func getDownloadLocation(_ item: OhiaItem) throws -> String?
    
    @MainActor
    func setItemNew(_ item: OhiaItem, new: Bool) throws
    
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

    @MainActor
    func setSecureBookmark(_ bookmark: Data, for url: URL) throws

    @MainActor
    func getSecureBookmarkFor(_ url: URL) throws -> Data?
    
    @MainActor
    func clearNewItems() throws
    
    @MainActor
    func resetDatabase() -> Bool
}

enum DataStorageServiceError: Error {
    case noDatabase
    case noItemCollection
    case noUserCollection
    case noBookmarksCollection
}

extension DataStorageServiceError: CustomStringConvertible {
    var description: String {
        switch self {
        case .noDatabase:
            return "Unable to open the database"
            
        case .noItemCollection:
            return "Missing item collection"
            
        case .noUserCollection:
            return "Missing user collection"
            
        case .noBookmarksCollection:
            return "Missing bookmarks collection"
        }
    }
}

extension DataStorageServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noDatabase:
            return NSLocalizedString("The database could not be opened.",
                                     comment: "")
            
        case .noItemCollection:
            return NSLocalizedString("The database is missing the item collection.",
                                     comment: "")
            
        case .noUserCollection:
            return NSLocalizedString("The database is missing the user data collection",
                                     comment: "")
            
        case .noBookmarksCollection:
            return NSLocalizedString("The database is missing the bookmarks collection",
                                     comment: "")
        }
    }
    
    var recoverySuggestion: String? {
        return NSLocalizedString("It may be possible that the database has become corrupt. It may be possible to fix this by deleting the database",
                                 comment: "")
    }
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
