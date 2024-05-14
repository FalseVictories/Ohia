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

@MainActor
protocol DataStorageService: Sendable {
    func openDatabase() throws
    func openDataStorage(for username: String) throws
    
    func closeDataStorage() throws
    
    func loadItems() throws -> [OhiaItem]
    
    func addItem(_ item: OhiaItem) throws
    
    func setItemDownloaded(_ item: OhiaItem, downloaded: Bool) throws
    
    func setItemDownloadLocation(_ item: OhiaItem, location: String) throws
    func getDownloadLocation(_ item: OhiaItem) throws -> String?

    func setItemNew(_ item: OhiaItem, new: Bool) throws
    func updateItem(_ item: OhiaItem) throws
    
    func setUser(_ user: OhiaUser) throws
    func getUser() throws -> OhiaUser?

    func getCurrentUsername() throws -> String?
    func setCurrentUsername(_ username: String) throws
    func clearCurrentUsername() throws

    func setSummary(_ summary: OhiaCollectionSummary) throws
    func getSummary() throws -> OhiaCollectionSummary

    func setSecureBookmark(_ bookmark: Data, for url: URL) throws
    func getSecureBookmarkFor(_ url: URL) throws -> Data?

    func clearNewItems() throws
    
    func resetDatabase() -> Bool
    
    func setArtistFolders(_ folders: [String], for url: URL) throws
    func artistFolders(for url: URL) throws -> [String]?
}

enum DataStorageServiceError: Error {
    case noDatabase
    case noItemCollection
    case noUserCollection
    case noBookmarksCollection
    case noScopelessCollection
    case errorDeletingUsername
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
            
        case .noScopelessCollection:
            return "Missing nonscoped collection"
            
        case .errorDeletingUsername:
            return "Error deleting username"
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
            
        case .noScopelessCollection:
            return NSLocalizedString("The database is missing the nonscoped collection",
                                     comment: "")
            
        case .errorDeletingUsername:
            return NSLocalizedString("Error deleting username", comment: "")
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
