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
import Packet
import SwiftUI
import Zipper

struct DownloadOptions: Sendable {
    let decompress: Bool
    let createFolder: FolderStructure
    let overwrite: Bool
}

/// The two URLs that are used for downloading and unpacking
struct DownloadUrls {
    /// The eventual destination
    let url: URL
    
    /// The in-progress URL
    let downloadUrl: URL?
}

enum InternalError: Error {
    case noDownloadOptionsSet
    case noDownloadFileHandle
    case invalidFolderStructure
    case noInProgressUrl
}

enum ModelError: Error {
    case noDownloadAccess
}

extension ModelError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noDownloadAccess:
            return NSLocalizedString("No write access to selected download folder", comment: "")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noDownloadAccess:
            return NSLocalizedString("Changing the download folder",
                                     comment: "")
        }
    }
}

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
    
    enum DownloadType {
        case all
        case selected
        case new
    }
    
    @Published var isSignedIn: Bool = false {
        didSet {
            Logger.App.info("Signed in: \(self.isSignedIn, privacy: .public)")
            if isSignedIn {
                let loader = CollectionLoader()
                Task {
                    do {
                        try await loadCollection(using: loader)
                    } catch let error as NSError {
                        // Logging out will clear things that might be broken.
                        showError(error, isFatal: true)
                        doLogOut()
                    }
                }
            }
        }
    }
    
    func setIsSignedIn(value: Bool) {
        isSignedIn = value
    }
    
    @Published var items: [OhiaItem] = []
    @Published var username: String?
    @Published var name: String?
    @Published var collectionState: CollectionState = .none
    @Published var currentAction: Action = .none
    @Published var currentDownload: Int = 0
    @Published var totalDownloads: Int = 0
    @Published var avatarUrl: URL?
    
    @Published var selectedItems = Set<Int>()
    @Published var showErrorScreen = false
    @Published var showAboutScreen = false
    
    @Published var updatingCollection = false
    
    var idToItem: [Int: OhiaItem] = [:]
    var settings: SettingsModel = SettingsModel()
    
    var downloadFolderSecurityUrl: URL? // The URL with security clearance to access the downloads folder

    var downloadTask: Task<Void, Never>? // The task downloading items
    var downloadCollection: DownloadCollection<OhiaItem>? // The collection of items to be downloaded
    
    var oldSummary: OhiaCollectionSummary = .invalid
    var newSummary: OhiaCollectionSummary = .invalid

    var webModel: WebViewModel
    
    var currentDownloadOptions: DownloadOptions?

    var lastError: NSError?
    var lastErrorIsFatal: Bool = false
    
    init() {
        if ProcessInfo().environment["OHIA_RESET_SETTINGS"] != nil {
            Logger.App.info("Resetting user defaults")
            
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
        
        webModel = WebViewModel()
        webModel.setDelegate(self)

        registerDefaults()
        settings.loadDefaults()
        
        do {
            try dataStorageService.openDatabase()
        } catch {
            Logger.App.error("Error opening database")
        }
                
        updateSignedIn()
    }
    
    func closeDatabase() {
        do {
            try dataStorageService.closeDataStorage()
        } catch {
            Logger.App.error("Error closing database: \(error)")
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
            Logger.App.error("Error setting current user: \(error)")
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
        
    func markItem(downloaded: Bool) {
        // Get selected items
        
        do {
            try selectedItems.forEach {
                if let item = idToItem[$0] {
                    try dataStorageService.setItemDownloaded(item, downloaded: downloaded)
                    item.state = downloaded ? .downloaded : .none
                }
            }
        } catch {
            Logger.App.error("Error marking item as \(downloaded): \(error)")
        }
    }
    
    func downloadItemsOf(type: DownloadType) {
        guard let downloadFolder = settings.selectedDownloadFolder else {
            Logger.App.warning("No download folder selected")
            return
        }
        
        var itemsToDownload: [OhiaItem] = []
        var selectionClosure: (OhiaItem, Bool) -> Bool
        
        let downloadPreorders = settings.downloadPreorders
        
        switch type {
        case .all:
            selectionClosure = selectAllItems
            break
            
        case .new:
            selectionClosure = selectNewItems
            break
            
        case .selected:
            selectionClosure = selectSelected
            break
        }
        
        items.forEach {
            if selectionClosure($0, downloadPreorders) {
                $0.state = .waiting
                $0.lastError = nil

                if !settings.decompressDownloads {
                    itemsToDownload.append($0)
                } else if !settings.overwrite {
                    let folderExists = doesFolderMaybeExist(for: $0,
                                                            in: downloadFolder,
                                                            with: settings.createFolderStructure)
                    switch folderExists {
                    case .no:
                        itemsToDownload.append($0)
                        
                    case .yes:
                        $0.state = .downloaded
                        
                    case .maybe:
                        $0.state = .maybeDownloaded
                    }
                }
            }
        }
        
        do {
            try downloadItems(itemsToDownload)
        } catch let error as NSError {
            showError(error, isFatal: false)
        }
    }
    
    func downloadItems(_ downloadItems: [OhiaItem]) throws {
        guard currentAction != .downloading else {
            Logger.App.warning("Download already in progress")
            return
        }
        
        guard let downloadFolder = configService.downloadFolder else {
            Logger.App.warning("No download folder set")
            return
        }

        Logger.App.info("Download folder is \(downloadFolder)")
        Logger.App.info("Decompress: \(self.settings.decompressDownloads)")

        try accessDownloadFolder(downloadFolder)

        guard let downloadFolderSecurityUrl else {
            return
        }
        
        currentAction = .downloading
        totalDownloads = downloadItems.count
        currentDownload = 0

        currentDownloadOptions = DownloadOptions(decompress: settings.decompressDownloads,
                                                 createFolder: settings.createFolderStructure,
                                                 overwrite: settings.overwrite)
        
        let configService = self.configService
        let downloadCollection = DownloadCollection(items: downloadItems)
        self.downloadCollection = downloadCollection
        
        let options = DownloadServiceOptions(format: configService.fileFormat,
                                             maxDownloads: configService.maxDownloads)
        let downloadStream = downloadService.download(items: downloadCollection,
                                                      with: options,
                                                      updateClosure: processDownloadStream(item:filename:dataStream:))
        
        downloadTask = Task {
            for await (item, error) in downloadStream {
                let success = error == nil
                
                // item download is now complete
                currentDownload += 1
                item.set(state: success ? .downloaded : .error)
                if success {
                    do {
                        if let downloadUrls = item.downloadUrls {
                            let downloadPath = downloadUrls.url.path(percentEncoded: false)
                            if let downloadUrl = downloadUrls.downloadUrl {
                                let fm = FileManager.default
                                
                                if let currentDownloadOptions,
                                   currentDownloadOptions.overwrite {
                                    if fm.fileExists(atPath: downloadPath) {
                                        try fm.removeItem(at: downloadUrls.url)
                                    }
                                }
                                // Rename the in progress folder
                                try fm.moveItem(at: downloadUrl, to: downloadUrls.url)
                            }
                            try dataStorageService.setItemDownloadLocation(item,
                                                                           location: downloadPath)
                        }
                        
                        try dataStorageService.setItemDownloaded(item, downloaded: true)
                    } catch let error as NSError {
                        Logger.App.error("Error setting download results: \(error)")
                    }
                } else {
                    item.lastError = error
                    if item.retryCount < 5 {
                        item.set(state: .retrying)
                        await self.downloadCollection?.reschedule(element: item)
                    }
                }
            }
            
            downloadFolderSecurityUrl.stopAccessingSecurityScopedResource()
            self.downloadFolderSecurityUrl = nil
            currentAction = .none
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
    
    func updateCollection() {
        guard let username else {
            return
        }
        
        Task {
            let loader = CollectionLoader()
            try await updateCollectionFromServer(for: username, using: loader)
        }
    }
    
    func open(item: OhiaItem) {
        do {
            if let url = try dataStorageService.getDownloadLocation(item) {
                Logger.App.debug("Opening \(url)")
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url)
            }
        } catch {
            Logger.App.error("Error getting download location \(error)")
        }
    }
    
    func resetError() {
        lastErrorIsFatal = false
        lastError = nil
        showErrorScreen = false
    }
}

private extension OhiaViewModel {
    func showError(_ error: NSError,
                   isFatal: Bool) {
        lastErrorIsFatal = isFatal
        lastError = error
        showErrorScreen = true
    }
        
    func loadCollection(using loader: CollectionLoader) async throws {
        setState(.loading)

        try await realLoadCollection(using: loader)
    }
    
    func realLoadCollection(using loader: CollectionLoader) async throws {
        var serverSummary: BCCollectionSummary
        var user: OhiaUser?

        do {
            // Get the summary from the server
            serverSummary = try await getCollectionSummary(using: loader)
            newSummary = OhiaCollectionSummary(from: serverSummary)
        } catch {
            Logger.App.error("Error loading summary: \(error, privacy: .public)")
            
            throw error
        }
        
        var username: String
        do {
            // get the username from datastore or the server.
            username = try dataStorageService.getCurrentUsername() ?? serverSummary.username
            setUsername(newUsername: username)
            
            // Use the user's collection data
            try dataStorageService.openDataStorage(for: username)
            
            try dataStorageService.clearNewItems()
        } catch {
            Logger.App.error("Error opening database \(error, privacy: .public)")
            
            throw error
        }
        
        do {
            // get the summary from the datastore now the DB has been opened for the user
            oldSummary = try dataStorageService.getSummary()

            user = try dataStorageService.getUser()
            var realname: String?
            var imageUrl: URL?

            if user == nil || user?.userId == 0{
                Logger.App.debug("No name set")
                let fanData = try await loader.getFanData(for: username)
                realname = fanData.name
                imageUrl = fanData.imageUrl
                if realname != nil {
                    Logger.App.debug("Name from service: \(realname!)")
                } else {
                    Logger.App.warning("No name from service")
                }

                user = OhiaUser(userId: fanData.userId ?? 0, username: username, realname: realname, imageUrl: imageUrl)
                try dataStorageService.setUser(user!)
            } else {
                Logger.App.debug("Name from service: \(user?.realname ?? "<none>")")
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
            Logger.App.error("Error getting user details in: \(error, privacy: .public)")
            
            throw error
        }

        // This shouldn't ever happen
        guard let user else {
            Logger.App.error("No user found")

            fatalError("No user could be created")
        }

        do {
            // Try to load the collection from data store, fall back to the server
            if try !loadCollectionFromStorage(for: username) {
                Logger.App.info("Loading collection from server")
                
                do {
                    try await addCollectionFromServer(for: username, using: loader)
                } catch {
                    Logger.App.error("Error loading collection from server \(error, privacy: .public)")
                    
                    throw error
                }
            } else {
                // Check if we need to get an update from the server.
                let updateCount = calculateUpdateCount(lastItemId: oldSummary.mostRecentId,
                                                       itemIds: serverSummary.itemIds)

                Logger.App.info("   - need \(updateCount) items")

                do {
                    if (updateCount > 0) {
                        try dataStorageService.clearNewItems()
                        for item in items {
                            item.isNew = false
                        }
                        
                        try await loadCollectionUpdatesFor(user.userId,
                                                           count: updateCount,
                                                           using: loader)
                    }
                } catch {
                    Logger.App.error("Error getting collection update: \(error, privacy: .public)")
                    
                    throw error
                }
            }

            // Update our stored summary
            try dataStorageService.setSummary(newSummary)

            // Collection is loaded
            setState(.loaded)

            await loadImages()
        } catch let error as NSError {
            Logger.App.error("Error loading collection: \(error, privacy: .public)")
            
            throw error
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

        for try await item in await loader.downloadCollectionFor(userId, count: count) {
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
            Logger.App.info("Ignoring collection cache")
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
                
                idToItem[$0.id] = $0
            }
            
            // update the items
            self.items = items
        }
        
        return items.count > 0
    }
    
    func loadCollectionFromServer(for username: String, 
                                  using loader: CollectionLoader) async -> ThrowingItemStream {
        updatingCollection = true
        return await loader.downloadCollectionFor(username: username)
    }
    
    func addCollectionFromServer(for username: String,
                                 using loader: CollectionLoader) async throws {
        var batch: [BCItem] = []
        
        for try await item in await loadCollectionFromServer(for: username,
                                                             using: loader) {
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
    
    func updateCollectionFromServer(for username: String,
                                    using loader: CollectionLoader) async throws {
        var batch: [BCItem] = []
        
        for try await bcItem in await loadCollectionFromServer(for: username,
                                                             using: loader) {
            if let item = idToItem[bcItem.id] {
                if item.update(from: bcItem) {
                    try dataStorageService.updateItem(item)
                }
            } else {
                batch.append(bcItem)
                if batch.count > 20 {
                    addItems(batch, append: false)
                    batch.removeAll()
                }
            }
        }
        
        if batch.count > 0 {
            addItems(batch, append: false)
        }

        updatingCollection = false
        
        await loadImages()
    }
    
    func loadImages() async {
        let itemsWithoutImages = items.filter {
            $0.thumbnailUrl != nil
        }
        do {
            try await imageCacheService.downloadImages(for: itemsWithoutImages)
        } catch {
            Logger.App.error("Error getting images: \(error)")
        }
    }
    
    func addItems(_ batchItems: [BCItem], append: Bool = true) {
        for bcItem in batchItems {
            var tracklist: [OhiaTrack] = []
            bcItem.tracklist.forEach {
                tracklist.append(OhiaTrack(from: $0))
            }
            
            if items.contains(where: {
                $0.id == bcItem.id
            }) {
                Logger.App.debug("Items already contains id \(bcItem.id)")
                continue
            }
            
            let item = OhiaItem(id: bcItem.id,
                                title: bcItem.name,
                                artist: bcItem.artist,
                                tracks: tracklist,
                                added: bcItem.added,
                                isPreorder: bcItem.isPreorder,
                                isHidden: bcItem.isHidden,
                                isNew: !append,
                                downloadUrl: bcItem.downloadUrl)
            item.thumbnailUrl = bcItem.thumbnailUrl
            
            do {
                try dataStorageService.addItem(item)
                try dataStorageService.setItemNew(item, new: !append)
            } catch {
                Logger.App.error("Error adding \(item.artist) - \(item.title) to database")
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
            idToItem[item.id] = item
        }
    }

    func doLogOut() {
        Logger.App.info("Logging out")

        do {
            try dataStorageService.clearCurrentUsername()
        } catch {
            Logger.App.error("Error logging out: \(error)")
        }
        
        webModel.clear()
        items = []
        idToItem = [:]
        
        Task {
            await webModel.clearCookies()
            setState(.none)
            isSignedIn = false
        }
    }
    
    func selectAllItems(item: OhiaItem, downloadPreorders: Bool) -> Bool {
        if item.state != .downloaded {
            // Skip preorders
            if !downloadPreorders && item.isPreorder {
                return false
            } else {
                return true
            }
        }
        return false
    }
    
    func selectSelected(item: OhiaItem, downloadPreorders: Bool) -> Bool {
        return selectedItems.contains(item.id)
    }
    
    func selectNewItems(item: OhiaItem, downloadPreorders: Bool) -> Bool {
        return item.isNew
    }
    
    struct DownloadStream : Sendable{
        let options: DownloadOptions
        let downloadFolder: URL
        let zipper: Zipper?
        let fileHandle: FileHandle?
        let filename: String?
    }
    
    @MainActor
    func getDownloadStream(for item: OhiaItem,
                           with filename: String?) throws -> DownloadStream {
        guard let currentDownloadOptions,
              let downloadFolderSecurityUrl else {
            throw InternalError.noDownloadOptionsSet
        }
        
        var zipper: Zipper?
        var fileHandle: FileHandle?
        
        var url = downloadFolderSecurityUrl
        var downloadUrls: DownloadUrls
        
        if currentDownloadOptions.decompress &&
            currentDownloadOptions.createFolder != .none {
            downloadUrls = try createFolderStructure(for: item,
                                             into: url,
                                             with: currentDownloadOptions)
            guard let downloadUrl = downloadUrls.downloadUrl else {
                throw InternalError.noInProgressUrl
            }
            url = downloadUrl
        } else {
            downloadUrls = DownloadUrls(url: url, downloadUrl: nil)
        }
        
        item.setDownloadUrls(downloadUrls)
        
        if currentDownloadOptions.decompress {
            zipper = item.downloadProgress.startDecompressing(to: url,
                                                              with: currentDownloadOptions)
        } else {
            let filename = filename ?? "\(item.artist)-\(item.title).zip"
            let result = item.downloadProgress.startWritingDataFor(filename,
                                                                   in: url,
                                                                   with: currentDownloadOptions)
            switch result {
            case .success(let fh):
                fileHandle = fh
                
            case .failure(let error):
                throw error
            }
        }
        
        return DownloadStream(options: currentDownloadOptions,
                              downloadFolder: downloadFolderSecurityUrl,
                              zipper: zipper,
                              fileHandle: fileHandle,
                              filename: filename)
    }
    
    @Sendable nonisolated func processDownloadStream(item: OhiaItem,
                                                     filename: String?,
                                                     dataStream: AsyncThrowingDataChunks) async throws {
        let downloadStream = try await getDownloadStream(for: item, with: filename)
        
        if downloadStream.options.decompress,
            let zipper = downloadStream.zipper {
            try await zipper.consume(dataStream)
        } else {
            try await writeStream(item: item,
                                  downloadStream: downloadStream,
                                  dataStream: dataStream)
        }
    }
    
    nonisolated
    func writeStream(item: OhiaItem,
                     downloadStream: DownloadStream,
                     dataStream: AsyncThrowingDataChunks) async throws {
        guard let handle = downloadStream.fileHandle else {
            return
        }
        
        for try await buffer in dataStream {
            try handle.write(contentsOf: buffer)
            await item.downloadProgress.increaseBytesDownloaded(size: Int64(buffer.count))
        }
        
        try handle.close()
        if let filename = downloadStream.filename {
            let downloadUrl = downloadStream.downloadFolder.appending(path: filename)
            let downloadPath = downloadUrl.path(percentEncoded: false)
            let inProgress = downloadPath + ".ohia-download"
            
            Logger.Download.debug("Renaming \(inProgress) -> \(downloadPath)")
            try FileManager.default.moveItem(atPath: inProgress, toPath: downloadPath)
        }
    }
        
    nonisolated
    func createFolderStructure(for item: OhiaItem,
                               into downloadFolderUrl: URL,
                               with options: DownloadOptions) throws -> DownloadUrls {
        let fm = FileManager.default
        
        guard let dirPath = options.createFolder.dirPath(for: item) else {
            throw InternalError.invalidFolderStructure
        }
        
        let url = downloadFolderUrl.appending(path: dirPath,
                                        directoryHint: .isDirectory)
        let inProgressUrl = downloadFolderUrl.appending(path: dirPath + ".ohia-download")
        
        try fm.createDirectory(at: inProgressUrl, withIntermediateDirectories: true)

        return DownloadUrls(url: url, downloadUrl: inProgressUrl)
    }
    
    func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            ConfigurationKey.maxDownloads.rawValue: 6
        ])
    }
    
    func accessDownloadFolder(_ downloadFolder: URL) throws {
        guard let bookmarkData = try dataStorageService.getSecureBookmarkFor(downloadFolder) else {
            Logger.App.error("No access to \(downloadFolder)")
            throw ModelError.noDownloadAccess
        }

        var isStale = false
        downloadFolderSecurityUrl = try URL(resolvingBookmarkData: bookmarkData,
                                            options: .withSecurityScope,
                                            bookmarkDataIsStale: &isStale)

        if isStale {
            Logger.App.warning("Bookmark data is stale - trying again")
            if let bookmarkData = try settings.obtainSecurityBookmarkFor(downloadFolder) {
                downloadFolderSecurityUrl = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)

                if isStale {
                    Logger.App.error("Bookmark still stale")
                    return
                }
            } else {
                Logger.App.error("Unable to get bookmark data for \(downloadFolder)")
            }
        }
        
        guard let downloadFolderSecurityUrl else {
            Logger.App.error("No security url for \(downloadFolder)")
            throw ModelError.noDownloadAccess
        }

        if !downloadFolderSecurityUrl.startAccessingSecurityScopedResource() {
            Logger.App.error("Failed to access download URL")
            throw ModelError.noDownloadAccess
        }
    }
    
    enum FolderExistence: Equatable {
        case no
        case yes
        
        case maybe(String)
    }
        
    func doesFolderMaybeExist(for item: OhiaItem,
                              in downloadUrl: URL,
                              with requestedFolderStructure: FolderStructure) -> FolderExistence {
        // Check for the artist folder in toplevel, which is cached
        for folderStructure in FolderStructure.allCases {
            if let topLevel = folderStructure.dirPath(for: item) {
                Logger.App.debug("Searching for \(topLevel)")
                let albumUrl = downloadUrl.appending(components: topLevel, directoryHint: .isDirectory)
                if FileManager.default.fileExists(atPath: albumUrl.path(percentEncoded: false),
                                                  isDirectory: nil) {
                    return folderStructure == requestedFolderStructure ? .yes : .maybe("Matched with \(folderStructure.rawValue)")
                }
            }
        }
        
        return .no
    }
}

extension OhiaViewModel: WebViewModelDelegate {
    nonisolated func webViewDidLogin() {
        Task {
            await setIsSignedIn(value: true)
        }
    }
}
