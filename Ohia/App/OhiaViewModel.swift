//
//  OhiaViewModel.swift
//  Ohia
//
//  Created by iain on 08/10/2023.
//

import Foundation
import BCKit
import Combine
import Dependencies
import Foundation
import OSLog
import SwiftUI

@MainActor
class OhiaViewModel: ObservableObject {
    @Dependency(\.configurationService) var configService: any ConfigurationService
    @Dependency(\.cookieService) var cookieService: any CookieService
    @Dependency(\.dataStorageService) var dataStorageService: any DataStorageService
    @Dependency(\.downloadService) var downloadService: any DownloadService
    @Dependency(\.imageCacheService) var imageCacheService: any ImageCacheService
    
    enum CollectionState {
        case none
        case loading
        case loaded
    }
    
    enum Action {
        case none
        case downloading
    }
    
    @Published var isSignedIn: Bool = false {
        didSet {
            Logger.Model.info("Signed in: \(self.isSignedIn, privacy: .public)")
            if isSignedIn {
                let loader = CollectionLoader()
                loadCollection(using: loader)
            }
        }
    }
    
    @Published var items: [OhiaItem] = []
    @Published var username: String?
    @Published var name: String?
    @Published var collectionState: CollectionState = .none
    @Published var currentAction: Action = .none
    @Published var currentDownload: Int = 0
    @Published var totalDownloads: Int = 0
    @Published var avatarUrl: URL?
    
    var settings: SettingsModel = SettingsModel()
    
    var downloadFolderSecurityUrl: URL?

    var downloadTask: Task<Void, Never>?
    
    var oldSummary: OhiaCollectionSummary = .invalid
    var newSummary: OhiaCollectionSummary = .invalid

    var webModel: WebViewModel

    init() {
        settings.loadDefaults()
        webModel = WebViewModel()
        webModel.delegate = self

        updateSignedIn()
    }
    
    func closeDatabase() {
        do {
            try dataStorageService.closeDataStorage()
        } catch {
            Logger.Model.error("Error closing database: \(error)")
        }
    }
    
    func updateSignedIn() {
        if ProcessInfo().environment["OHIA_ALWAYS_LOG_IN"] != nil {
            Task {
                await webModel.clearCookies()
                isSignedIn = false
            }
            return
        }

        isSignedIn = cookieService.isLoggedIn
    }
    
    func setUsername(newUsername: String) {
        username = newUsername

        do {
            try dataStorageService.setCurrentUsername(newUsername)
        } catch {
            Logger.Model.error("Error setting current user: \(error)")
        }
    }
    
    func setName(_ newName: String) {
        name = newName
    }
    
    func setAvatar(_ newAvatar: URL?) {
        avatarUrl = newAvatar
    }
    
    func setState(_ state: CollectionState) {
        self.collectionState = state
    }
    
    func setAction(_ action: Action) {
        self.currentAction = action
    }
        
    func downloadItems() throws {
        guard currentAction != .downloading else {
            Logger.Model.warning("Download already in progress")
            return
        }
        
        guard let downloadFolder = configService.downloadFolder else {
            Logger.Model.warning("No download folder set")
            return
        }

        guard let bookmarkData = try dataStorageService.getSecureBookmarkFor(downloadFolder) else {
            Logger.Model.error("No access to \(downloadFolder)")
            return
        }

        var isStale = false
        downloadFolderSecurityUrl = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)

        guard let downloadFolderSecurityUrl else {
            return
        }

        if isStale {
            // FIXME: Get the bookmark data again
            Logger.Model.warning("Bookmark data is stale")
            return
        }

        if !downloadFolderSecurityUrl.startAccessingSecurityScopedResource() {
            Logger.Model.error("Failed to access download URL")
            return
        }

        currentAction = .downloading

        var downloadItems: [OhiaItem] = []
        let downloadPreorders = settings.downloadPreorders
        items.forEach {
            if $0.state != .downloaded {
                // Skip preorders
                if !settings.downloadPreorders && $0.isPreorder {
                    Logger.Model.debug("Skipping \($0.artist) \($0.title)")
                } else {
                    $0.state = .waiting
                    downloadItems.append($0)
                }
            }
        }

        totalDownloads = downloadItems.count
        currentDownload = 0

        downloadTask = Task {
            let downloadStream = downloadService.download(items: downloadItems,
                                                          ofType: configService.fileFormat,
                                                          to: downloadFolderSecurityUrl)
            do {
                for try await (item, success) in downloadStream {
                    currentDownload += 1
                    item.set(state: success ? .downloaded : .cancelled)
                    if success {
                        try dataStorageService.setItemDownloaded(item)
                    }
                }

                downloadFolderSecurityUrl.stopAccessingSecurityScopedResource()
                self.downloadFolderSecurityUrl = nil
            } catch {
                Logger.Model.error("Error in download task: \(error)")
                downloadFolderSecurityUrl.stopAccessingSecurityScopedResource()
                self.downloadFolderSecurityUrl = nil
            }
        }
    }
    
    func cancelAllDownloads() {
        downloadTask?.cancel()
        downloadService.cancelDownloads()
        downloadFolderSecurityUrl?.stopAccessingSecurityScopedResource()
        downloadFolderSecurityUrl = nil

        setAction(.none)
        
        items.forEach {
            if $0.state != .downloaded {
                $0.set(state: .cancelled)
            }
        }
    }
    
    func logOut() {
        doLogOut()
    }
}

private extension OhiaViewModel {
    func loadCollection(using loader: CollectionLoader) {
        setState(.loading)

        Task {
            var serverSummary: BCCollectionSummary
            var user: OhiaUser?

            do {
                // Get the summary from the server
                serverSummary = try await getCollectionSummary(using: loader)
                newSummary = OhiaCollectionSummary(from: serverSummary)

                // get the username from datastore or the server.
                let username = try dataStorageService.getCurrentUsername() ?? serverSummary.username
                setUsername(newUsername: username)

                // Use the user's collection data
                try dataStorageService.openDataStorage(for: username)

                // get the summary from the datastore now the DB has been opened for the user
                oldSummary = try dataStorageService.getSummary()

                user = try dataStorageService.getUser()
                var realname: String?
                var imageUrl: URL?

                if user == nil || user?.userId == 0{
                    Logger.Model.debug("No name set")
                    let fanData = try await loader.getFanData(for: username)
                    realname = fanData.name
                    imageUrl = fanData.imageUrl
                    if realname != nil {
                        Logger.Model.debug("Name from service: \(realname!)")
                    } else {
                        Logger.Model.warning("No name from service")
                    }

                    user = OhiaUser(userId: fanData.userId ?? 0, username: username, realname: realname, imageUrl: imageUrl)
                    try dataStorageService.setUser(user!)
                } else {
                    Logger.Model.debug("Name from service: \(user?.realname ?? "<none>")")
                    realname = user!.realname
                    imageUrl = user!.imageUrl
                }

                if let realname {
                    setName(realname)
                }

                if let imageUrl {
                    setAvatar(imageUrl)
                }
            } catch let error as NSError {
                Logger.Model.error("Error logging in: \(error)")
                setState(.none)
                isSignedIn = false
                return
            }

            guard let user,
                  let username else {
                Logger.Model.error("No user found")

                doLogOut()
                return
            }

            do {
                // Try to load the collection from data store, fall back to the server
                if try !loadCollectionFromStorage(for: username) {
                    Logger.Model.info("Loading collection from server")
                    try await loadCollectionFromServer(for: username, using: loader)
                } else {
                    // Check if we need to get an update from the server.
                    let updateCount = calculateUpdateCount(lastItemId: oldSummary.mostRecentId,
                                                           itemIds: serverSummary.itemIds)

                    Logger.Model.info("   - need \(updateCount) items")

                    if (updateCount > 0) {
                        try await loadCollectionUpdatesFor(user.userId,
                                                           count: updateCount,
                                                           using: loader)
                    }
                }

                // Update our stored summary
                try dataStorageService.setSummary(newSummary)

                // Collection is loaded
                setState(.loaded)

                await loadImages()
            } catch let error as NSError {
                Logger.Model.error("Error loading collection: \(error, privacy: .public)")
                setState(.none)
                return
            }
        }
    }
    
    /// Find how many items have been added since the current most recent item
    func calculateUpdateCount(lastItemId: Int, itemIds: [Int]) -> Int {
        var i = 0
        for id in itemIds {
            if id == lastItemId {
                break
            }

            i += 1
        }

        return i
    }

    func loadCollectionUpdatesFor(_ userId: Int, count: Int, using loader: CollectionLoader) async throws {
        var batch: [BCItem] = []

        for try await item in loader.downloadCollectionFor(userId, count: count) {
            batch.append(item)
            if batch.count > 20 {
                addItems(batch, append: false)
                batch.removeAll()
            }
        }

        if batch.count > 0 {
            addItems(batch, append: false)
        }
    }
    
    func getCollectionSummary(using loader: CollectionLoader) async throws -> BCCollectionSummary {
        return try await loader.getCollectionInfo()
    }
    
    func loadCollectionFromStorage(for username: String) throws -> Bool {
        if ProcessInfo().environment["OHIA_IGNORE_COLLECTION_CACHE"] != nil {
            Logger.Model.info("Ignoring collection cache")
            return false
        }
        
        try dataStorageService.openDataStorage(for: username)
        
        let items = try dataStorageService.loadItems()
        if items.count > 0 {
            // Load any images from the cache
            items.forEach {
                if let image = imageCacheService.getThumbnail(for: $0) {
                    $0.thumbnail = image
                    $0.thumbnailUrl = nil  // Don't need to download an image anymore
                }
            }
            
            // update the items
            self.items = items
        }
        
        return items.count > 0
    }
    
    func loadCollectionFromServer(for username: String, using loader: CollectionLoader) async throws {
        var batch: [BCItem] = []
        
        for try await item in loader.downloadCollectionFor(username: username) {
            batch.append(item)
            if batch.count > 20 {
                addItems(batch)
                batch.removeAll()
            }
        }

        if batch.count > 0 {
            addItems(batch)
        }
    }
    
    func loadImages() async {
        let itemsWithoutImages = items.filter {
            $0.thumbnailUrl != nil
        }
        do {
            try await imageCacheService.downloadImages(for: itemsWithoutImages)
        } catch {
            Logger.Model.error("Error getting images: \(error)")
        }
    }
    
    func addItems(_ batchItems: [BCItem], append: Bool = true) {
        for bcItem in batchItems {
            let item = OhiaItem(id: bcItem.id, title: bcItem.name, artist: bcItem.artist, 
                                added: bcItem.added, isPreorder: bcItem.isPreorder, isHidden: bcItem.isHidden,
                                downloadUrl: bcItem.downloadUrl)
            item.thumbnailUrl = bcItem.thumbnailUrl
            
            do {
                try dataStorageService.addItem(item)
            } catch {
                Logger.Model.error("Error adding \(item.artist) - \(item.title) to database")
            }
            
            if let image = imageCacheService.getThumbnail(for: item) {
                item.thumbnail = image
                item.thumbnailUrl = nil  // Don't need to download an image anymore
            }

            if append {
                items.append(item)
            } else {
                items.insert(item, at: 0)
            }
        }
    }

    func doLogOut() {
        Logger.Model.info("Logging out")

        webModel.clear()
        items = []
        
        Task {
            await webModel.clearCookies()
            setState(.none)
            isSignedIn = false
        }
    }
}

extension OhiaViewModel: WebViewModelDelegate {
    func webViewDidLogin() {
        isSignedIn = true
    }
}
