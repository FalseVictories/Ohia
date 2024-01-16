//
//  LiveDataStorageService.swift
//  Ohia
//
//  Created by iain on 22/10/2023.
//

import BCKit
import CouchbaseLiteSwift
import Foundation
import OSLog

@MainActor
final class LiveDataStorageService: DataStorageService {
    static let dbFolderPath = "com.falsevictories.ohia"
    static let dbName = "ohia-db"
    static let collectionName = "bcItems"
    static let userDataCollectionName = "userdata"
    static let bookmarksCollectionName = "bookmarks"

    private struct DataBaseKeys {
        static let artist = "artist"
        static let title = "title"
        static let downloadUrl = "downloadUrl"
        static let thumbnailUrl = "thumbnailUrl"
        static let bcid = "bcid"
        static let isDownloaded = "isDownloaded"
        static let added = "added"
        static let isPreorder = "isPreorder"
        static let isHidden = "isHidden"
    }

    var database: Database?
    var collection: Collection?
    var userDataCollection: Collection?
    var bookmarksCollection: Collection?

    func openDataStorage(for username: String) throws {
        Logger.DataStorageService.info("Opening database for \(username)")

        if database == nil {
            try openDatabase()
        }

        guard let database else {
            throw DataStorageServiceError.noDatabase("No database")
        }

        // Store items by username
        collection = try database.createCollection(name: LiveDataStorageService.collectionName,
                                                   scope: username)
        if collection == nil {
            throw DataStorageServiceError.noCollection("Missing item collection")
        }

        // store user data in a separate collection scoped to the username
        userDataCollection = try database.createCollection(name: LiveDataStorageService.userDataCollectionName,
                                                           scope: username)
        if userDataCollection == nil {
            throw DataStorageServiceError.noCollection("Missing user collection")
        }
    }

    func closeDataStorage() throws {
        Logger.DataStorageService.info("Closing database")
        try database?.close()
    }

    func loadItems() throws -> [OhiaItem] {
        guard let collection else {
            throw DataStorageServiceError.noCollection("Missing item collection")
        }

        Logger.DataStorageService.debug("Loading collection from database")

        // Newest first
        let ordering = Ordering.property(DataBaseKeys.added).descending()
        // Select all results from the collection
        let query = QueryBuilder
            .select(SelectResult.all())
            .from(DataSource.collection(collection))
            .orderBy(ordering)

        var results: [OhiaItem] = []

        // Convert the resultset into OhiaItems
        for document in try query.execute() {
            guard let docProps = document.dictionary(at: 0) else {
                Logger.DataStorageService.warning("Missing doc props")
                continue
            }

            guard let title = docProps.string(forKey: DataBaseKeys.title),
                  let artist = docProps.string(forKey: DataBaseKeys.artist),
                  let downloadUrl = docProps.string(forKey: DataBaseKeys.downloadUrl) else {
                Logger.DataStorageService.warning("Missing data")
                continue
            }

            let item = OhiaItem(id: docProps.int(forKey: DataBaseKeys.bcid),
                                title: title,
                                artist: artist,
                                added: docProps.int(forKey: DataBaseKeys.added),
                                isPreorder: docProps.boolean(forKey: DataBaseKeys.isPreorder),
                                isHidden: docProps.boolean(forKey: DataBaseKeys.isHidden),
                                downloadUrl: URL(string: downloadUrl)!)
            if let thumbnail = docProps.string(forKey: DataBaseKeys.thumbnailUrl) {
                item.thumbnailUrl = URL(string:thumbnail)
            }

            item.set(state: docProps.boolean(forKey: DataBaseKeys.isDownloaded) ? .downloaded : .none)

            results.append(item)
        }

        Logger.DataStorageService.debug("Loaded \(results.count) items from database")
        return results
    }

    func addItem(_ item: OhiaItem) throws {
        guard let collection else {
            throw DataStorageServiceError.noCollection("Missing item collection")
        }

        Logger.DataStorageService.debug("Adding \(item.artist) - \(item.title) to database")

        let document = MutableDocument(id: String(describing: item.id))
        document.setValue(item.id, forKey: DataBaseKeys.bcid)
        document.setValue(item.artist, forKey: DataBaseKeys.artist)
        document.setValue(item.title, forKey: DataBaseKeys.title)
        document.setValue(item.downloadUrl.absoluteString, forKey: DataBaseKeys.downloadUrl)
        document.setValue(item.added, forKey: DataBaseKeys.added)
        document.setBoolean(item.isPreorder, forKey: DataBaseKeys.isPreorder)
        document.setBoolean(item.isHidden, forKey: DataBaseKeys.isHidden)
        if let thumbnail = item.thumbnailUrl {
            document.setValue(thumbnail.absoluteString, forKey: DataBaseKeys.thumbnailUrl)
        }

        try collection.save(document: document)
    }

    func setItemDownloaded(_ item: OhiaItem,
                           downloaded: Bool) throws {
        guard let collection else {
            throw DataStorageServiceError.noCollection("Missing item collection")
        }

        guard let document = try collection.document(id: String(describing: item.id)) else {
            return
        }

        let mutableDoc = document.toMutable()
        mutableDoc.setBoolean(downloaded, forKey: DataBaseKeys.isDownloaded)

        try collection.save(document: mutableDoc)
    }

    func setUser(_ data: OhiaUser) throws {
        guard let userDataCollection else {
            throw DataStorageServiceError.noCollection("Missing user collection")
        }

        let mutableDoc = MutableDocument(id: "User Data")
        mutableDoc.setValue(data.username, forKey: "username")
        mutableDoc.setValue(data.realname, forKey: "realname")
        if let imageUrl = data.imageUrl {
            mutableDoc.setValue(imageUrl.absoluteString, forKey: "avatarUrl")
        }
        try userDataCollection.save(document: mutableDoc)
    }

    func getCurrentUsername() throws -> String? {
        if database == nil {
            try openDatabase()
        }

        guard let database else {
            throw DataStorageServiceError.noDatabase("Missing database")
        }

        guard let doc = try database.defaultCollection().document(id: "currentUsername") else {
            return nil
        }

        return doc.string(forKey: "username")
    }

    func setCurrentUsername(_ username: String) throws {
        if database == nil {
            try openDatabase()
        }

        guard let database else {
            throw DataStorageServiceError.noDatabase("Missing database")
        }

        let doc = try database.defaultCollection().document(id: "currentUsername")
        let mDoc = doc?.toMutable() ?? MutableDocument(id: "currentUsername")

        mDoc.setString(username, forKey: "username")
        try database.defaultCollection().save(document: mDoc)
    }

    func getUser() throws -> OhiaUser? {
        guard let userDataCollection else {
            throw DataStorageServiceError.noCollection("Missing user data collection")
        }

        guard let doc = try userDataCollection.document(id: "User Data"),
              let username = doc.string(forKey: "username") else {
            return nil
        }

        var imageUrl: URL? = nil
        if let avatarUrlString = doc.string(forKey: "avatarUrl") {
            imageUrl = URL(string: avatarUrlString)
        }
        return OhiaUser(userId: doc.int(forKey: "userId"),
                        username: username,
                        realname: doc.string(forKey: "realname"),
                        imageUrl: imageUrl)
    }

    func setSummary(_ summary: OhiaCollectionSummary) throws {
        guard let userDataCollection else {
            throw DataStorageServiceError.noCollection("Missing user data collection")
        }

        let mutableDoc = MutableDocument(id: "Summary")
        mutableDoc.setValue(summary.count, forKey: "collectionCount")
        mutableDoc.setValue(summary.mostRecentId, forKey: "mostRecentId")

        try userDataCollection.save(document: mutableDoc)
    }

    func getSummary() throws -> OhiaCollectionSummary {
        guard let userDataCollection else {
            throw DataStorageServiceError.noCollection("Missing user data collection")
        }

        guard let doc = try userDataCollection.document(id: "Summary") else {
            return .invalid
        }

        let collectionCount = doc.int(forKey: "collectionCount")
        let mostRecentId = doc.int(forKey: "mostRecentId")

        if collectionCount == 0 && mostRecentId == 0 {
            return .invalid
        }
        return OhiaCollectionSummary(count: collectionCount, mostRecentId: mostRecentId)
    }

    func setSecureBookmark(_ bookmark: Data, for url: URL) throws {
        guard let bookmarksCollection else {
            throw DataStorageServiceError.noCollection("Missing bookmarks collection")
        }

        if let urlData = url.absoluteString.data(using: .utf8) {
            let bookmark64 = bookmark.base64EncodedString()
            let url64 = urlData.base64EncodedString()

            let doc = MutableDocument(id: url64)
            doc.setString(bookmark64, forKey: "bookmark")

            try bookmarksCollection.save(document: doc)
        }
    }

    func getSecureBookmarkFor(_ url: URL) throws -> Data? {
        guard let bookmarksCollection else {
            throw DataStorageServiceError.noCollection("Missing bookmarks collection")
        }

        if let urlData = url.absoluteString.data(using: .utf8) {
            let doc = try bookmarksCollection.document(id: urlData.base64EncodedString())
            if let bookmark64 = doc?.string(forKey: "bookmark") {
                return Data(base64Encoded: bookmark64, options: .ignoreUnknownCharacters)
            }
        }

        return nil
    }
}

private extension LiveDataStorageService {
    func openDatabase() throws {
        let fm = FileManager.default

        let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let ohiaUrl = cachesDir.appending(path: LiveDataStorageService.dbFolderPath, directoryHint: .isDirectory)

        let ohiaDir = ohiaUrl.path(percentEncoded: false)

        Logger.DataStorageService.debug("Using database in \(ohiaDir)")

        if !fm.fileExists(atPath: ohiaDir) {
            Logger.DataStorageService.debug("Creating database folder")
            try fm.createDirectory(at: ohiaUrl, withIntermediateDirectories: true)
        }

        var options = DatabaseConfiguration()
        options.directory = ohiaDir

        database = try Database(name: LiveDataStorageService.dbName, config: options)

        guard database != nil else {
            throw DataStorageServiceError.noDatabase("No database")
        }

        bookmarksCollection = try database?.createCollection(name: LiveDataStorageService.bookmarksCollectionName)
        guard bookmarksCollection != nil else {
            throw DataStorageServiceError.noCollection("Unable to find bookmarks collection")
        }
    }
}
