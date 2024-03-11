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

struct DownloadOptions: Sendable {
    let decompress: Bool
    let createFolder: FolderStructure
    let overwrite: Bool
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
            Logger.Model.info("Signed in: \(self.isSignedIn, privacy: .public)")
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
    @Published var errorShown = false
    
    var idToItem: [Int: OhiaItem] = [:]
    var settings: SettingsModel = SettingsModel()
    
    var downloadFolderSecurityUrl: URL?

    var downloadTask: Task<Void, Never>?
    
    var oldSummary: OhiaCollectionSummary = .invalid
    var newSummary: OhiaCollectionSummary = .invalid

    var webModel: WebViewModel
    
    var currentDownloadOptions: DownloadOptions?

    var lastError: NSError?
    var lastErrorIsFatal: Bool = false
    
    init() {
        if ProcessInfo().environment["OHIA_RESET_SETTINGS"] != nil {
            Logger.Model.info("Resetting user defaults")
            
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
        
        webModel = WebViewModel()
        webModel.setDelegate(self)

        registerDefaults()
        settings.loadDefaults()
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
            Logger.Model.error("Error marking item as \(downloaded): \(error)")
        }
    }
    
    func downloadItemsOf(type: DownloadType) {
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
                itemsToDownload.append($0)
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
            Logger.Model.warning("Download already in progress")
            return
        }
        
        guard let downloadFolder = configService.downloadFolder else {
            Logger.Model.warning("No download folder set")
            return
        }

        Logger.Model.info("Download folder is \(downloadFolder)")
        Logger.Model.info("Decompress: \(self.settings.decompressDownloads)")

        guard let bookmarkData = try dataStorageService.getSecureBookmarkFor(downloadFolder) else {
            Logger.Model.error("No access to \(downloadFolder)")
            throw ModelError.noDownloadAccess
        }

        var isStale = false
        downloadFolderSecurityUrl = try URL(resolvingBookmarkData: bookmarkData,
                                            options: .withSecurityScope,
                                            bookmarkDataIsStale: &isStale)

        if isStale {
            Logger.Model.warning("Bookmark data is stale - trying again")
            if let bookmarkData = try settings.obtainSecurityBookmarkFor(downloadFolder) {
                downloadFolderSecurityUrl = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)

                if isStale {
                    Logger.Model.error("Bookmark still stale")
                    return
                }
            } else {
                Logger.Model.error("Unable to get bookmark data for \(downloadFolder)")
            }
        }

        guard let downloadFolderSecurityUrl else {
            Logger.Model.error("No security url for \(downloadFolder)")
            throw ModelError.noDownloadAccess
        }

        if !downloadFolderSecurityUrl.startAccessingSecurityScopedResource() {
            Logger.Model.error("Failed to access download URL")
            throw ModelError.noDownloadAccess
        }

        currentAction = .downloading
        totalDownloads = downloadItems.count
        currentDownload = 0

        currentDownloadOptions = DownloadOptions(decompress: settings.decompressDownloads,
                                                 createFolder: settings.createFolderStructure,
                                                 overwrite: false)
        
        downloadTask = Task {
            let options = DownloadServiceOptions(format: configService.fileFormat,
                                                 maxDownloads: configService.maxDownloads)
            let downloadStream = downloadService.download(items: downloadItems,
                                                          with: options,
                                                          updateClosure: processDownloadStream(item:filename:dataStream:))
            for await (item, error) in downloadStream {
                let success = error == nil
                
                // item download is now complete
                currentDownload += 1
                item.set(state: success ? .downloaded : .error)
                if success {
                    do {
                        if let localFolder = item.localFolder {
                            try dataStorageService.setItemDownloadLocation(item, location: localFolder.path(percentEncoded: false))
                        }
                        try dataStorageService.setItemDownloaded(item, downloaded: true)
                    } catch let error as NSError {
                        Logger.Model.error("Error setting download results: \(error)")
                    }
                } else {
                    item.lastError = error
                }
            }
            
            downloadFolderSecurityUrl.stopAccessingSecurityScopedResource()
            self.downloadFolderSecurityUrl = nil
            currentAction = .none
            
//            } catch let error as NSError {
//                Logger.Model.error("Error in download task: \(error)")
//                downloadFolderSecurityUrl.stopAccessingSecurityScopedResource()
//                self.downloadFolderSecurityUrl = nil
//                currentAction = .none
//
//                showError(error, isFatal: false)
//            }
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
    
    func open(item: OhiaItem) {
        do {
            if let url = try dataStorageService.getDownloadLocation(item) {
                Logger.Model.debug("Opening \(url)")
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url)
            }
        } catch {
            Logger.Model.error("Error getting download location \(error)")
        }
    }
    
    func resetError() {
        lastErrorIsFatal = false
        lastError = nil
        errorShown = false
    }
}

private extension OhiaViewModel {
    func showError(_ error: NSError,
                   isFatal: Bool) {
        lastErrorIsFatal = isFatal
        lastError = error
        errorShown = true
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
            Logger.Model.error("Error loading summary: \(error, privacy: .public)")
            
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
            Logger.Model.error("Error opening database \(error, privacy: .public)")
            
            throw error
        }
        
        do {
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
            Logger.Model.error("Error getting user details in: \(error, privacy: .public)")
            
            throw error
        }

        // This shouldn't ever happen
        guard let user else {
            Logger.Model.error("No user found")

            fatalError("No user could be created")
        }

        do {
            // Try to load the collection from data store, fall back to the server
            if try !loadCollectionFromStorage(for: username) {
                Logger.Model.info("Loading collection from server")
                
                do {
                    try await loadCollectionFromServer(for: username, using: loader)
                } catch {
                    Logger.Model.error("Error loading collection from server \(error, privacy: .public)")
                    
                    throw error
                }
                
            } else {
                // Check if we need to get an update from the server.
                let updateCount = calculateUpdateCount(lastItemId: oldSummary.mostRecentId,
                                                       itemIds: serverSummary.itemIds)

                Logger.Model.info("   - need \(updateCount) items")

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
                    Logger.Model.error("Error getting collection update: \(error, privacy: .public)")
                    
                    throw error
                }
            }

            // Update our stored summary
            try dataStorageService.setSummary(newSummary)

            // Collection is loaded
            setState(.loaded)

            await loadImages()
        } catch let error as NSError {
            Logger.Model.error("Error loading collection: \(error, privacy: .public)")
            
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
                
                idToItem[$0.id] = $0
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
            idToItem[item.id] = item
        }
    }

    func doLogOut() {
        Logger.Model.info("Logging out")

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
    
    @Sendable nonisolated func processDownloadStream(item: OhiaItem, filename: String?, dataStream: URLSession.AsyncBytes) async throws {
        guard let currentDownloadOptions = await currentDownloadOptions else {
            return
        }
        
        if currentDownloadOptions.decompress {
            try await unpackStream(item: item, filename: filename, dataStream: dataStream)
        } else {
            try await writeStream(item: item, filename: filename, dataStream: dataStream)
        }
    }
    
    nonisolated
    func unpackStream(item: OhiaItem, filename: String?, dataStream: URLSession.AsyncBytes) async throws {
        guard let downloadFolderSecurityUrl = await downloadFolderSecurityUrl,
              let currentDownloadOptions = await currentDownloadOptions else {
            return
        }
        
        var url = downloadFolderSecurityUrl
        if currentDownloadOptions.createFolder != .none {
            url = try createFolderStructure(for: item,
                                            into: url,
                                            with: currentDownloadOptions)
        }
        
        await item.setLocalFolder(url)
        let zipper = await item.downloadProgress.startDecompressing(to: url,
                                                                    with: currentDownloadOptions)
        try await zipper.consume(dataStream)
    }
    
    nonisolated
    func writeStream(item: OhiaItem,
                     filename: String?,
                     dataStream: URLSession.AsyncBytes) async throws {
        guard let downloadFolderSecurityUrl = await downloadFolderSecurityUrl,
              let currentDownloadOptions = await currentDownloadOptions else {
            return
        }
        
        guard let handle = try await item.downloadProgress.startWritingDataFor(filename ?? "\(item.artist)-\(item.title).zip",
                                                      in: downloadFolderSecurityUrl,
                                                                               with: currentDownloadOptions) else {
            return
        }
        
        await item.setLocalFolder(downloadFolderSecurityUrl)
        
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: LiveDownloadService.bufferSize)
        defer {
            buffer.deallocate()
        }
        
        var count = 0
        var totalCount = 0
        
        for try await byte in dataStream {
            // add byte to the buffer
            buffer[count] = byte
            count += 1
            totalCount += 1
            
            // write the data when the buffer is full
            if count >= LiveDownloadService.bufferSize {
                Logger.DownloadService.debug("Adding \(count) bytes to file: \(totalCount)")
                
                let dataBuffer = Data(bytesNoCopy: buffer,
                                      count: LiveDownloadService.bufferSize,
                                      deallocator: .none)
                
                try handle.write(contentsOf: dataBuffer)
                
                await item.downloadProgress.increaseBytesDownloaded(size: Int64(count))
                count = 0
            }
        }
        
        if count != 0 {
            Logger.DownloadService.debug("Adding \(count) bytes to file: \(totalCount)")
            let dataBuffer = Data(bytesNoCopy: buffer,
                                  count: count,
                                  deallocator: .none)
            try handle.write(contentsOf: dataBuffer)
            await item.downloadProgress.increaseBytesDownloaded(size: Int64(count))
        }
        
        try handle.close()
    }
    
    nonisolated
    func createFolderStructure(for item: OhiaItem,
                               into downloadUrl: URL,
                               with options: DownloadOptions) throws -> URL {
        guard options.createFolder != .none else {
            return downloadUrl
        }

        let fm = FileManager.default
        
        let dirPath = options.createFolder == .single ? "\(item.artist) - \(item.title)" : "\(item.artist)/\(item.title)"
        
        let url = downloadUrl.appending(path: dirPath,
                                        directoryHint: .isDirectory)
        
        try fm.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }
    
    func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            ConfigurationKey.maxDownloads.rawValue: 6
        ])
    }
}

extension OhiaViewModel: WebViewModelDelegate {
    nonisolated func webViewDidLogin() {
        Task {
            await setIsSignedIn(value: true)
        }
    }
}
