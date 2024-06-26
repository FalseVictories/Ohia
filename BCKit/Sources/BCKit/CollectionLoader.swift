//
//  File.swift
//
//
//  Created by iain on 05/10/2023.
//

import Dependencies
import Foundation
import Fuzi
import OSLog

let logger = Logger(subsystem:Bundle.main.bundleIdentifier!, category: "Collection")

public typealias ThrowingItemStream = AsyncThrowingStream<BCItem, Error>

enum CollectionLoaderError: Error {
    case noData(String)
    case noUserId(String)
    case invalidSummary
    case noItems(String)
}

extension CollectionLoaderError: CustomStringConvertible {
    var description: String {
        switch self {
        case .noData(let reason):
            return reason
            
        case .invalidSummary:
            return "Bandcamp returned an invalid summary"
            
        case .noItems(let reason):
            return reason
            
        case .noUserId(let reason):
            return reason
        }
    }
}

public final actor CollectionLoader {
    @Dependency(\.downloadService) var downloadService: any DownloadService
    
    private var dataBlob: DataBlob? // This is a very large datablob that remains for the life of CollectionLoader
    
    public init() {
    }
    
    public func getCollectionInfo() async throws -> BCCollectionSummary {
        let data = try await downloadService.collectionSummary()
        
        // We need the albumCache values to remain in file order.
        guard let summaryStr = String(data:data, encoding: .utf8) else {
            throw CollectionLoaderError.noData("The summary data returned from Bandcamp is invalid")
        }

        let summary = try JSON.parse(string: summaryStr)

        var itemIds: [Int] = []

        let userId = summary["fan_id"]
        let collectionSummary = summary["collection_summary"]

        guard let userId = userId as? Int else {
            let error = summary["error"]
            if let error = error as? Bool {
                if error {
                    if let message = summary["error_message"] {
                        throw CollectionLoaderError.noUserId("Error getting user id: \(message)")
                    }
                }
            }

            throw CollectionLoaderError.noUserId("Unknown error getting user id")
        }

        guard let collectionSummary else {
            throw CollectionLoaderError.noItems("Unknown error getting collection summary")
        }

        let username = collectionSummary["username"]
        let userPage = collectionSummary["url"]
        let albumCache = collectionSummary["tralbum_lookup"]

        guard let username = username as? String,
              let userPage = userPage as? String,
              let albumCache else {
            logger.warning("Invalid data in collection summary")
            throw CollectionLoaderError.invalidSummary
        }

        if let cache = albumCache.values {
            for item in cache {
                if let itemId = item["item_id"] as? Int {
                    itemIds.append(itemId)
                }
            }
        }

        let bcSummary = BCCollectionSummary(userId: userId,
                                            username: username,
                                            homepage: URL(string: userPage),
                                            itemIds: itemIds)
        return bcSummary
    }

    public func getFanData(for username: String) async throws -> FanData {
        let db = try await getDataBlob(for: username)
        return db.fan
    }
    
    public func downloadCollectionFor(username: String) -> ThrowingItemStream {
        return AsyncThrowingStream { continuation in
            Task {
                let db = try await getDataBlob(for: username)
                
                guard let userId = db.fan.userId else {
                    continuation.finish(throwing: CollectionLoaderError.noUserId("No fan_id in blob"))
                    return
                }

                try await downloadCollectionFor(userId,
                                                count: db.collectionCount,
                                                continuation: continuation)
            }
        }
    }

    public func downloadCollectionFor(_ userId: Int, 
                                      count: Int) -> AsyncThrowingStream<BCItem, Error> {
        return AsyncThrowingStream { contination in
            Task {
                try await downloadCollectionFor(userId, 
                                                count: count,
                                                continuation: contination)
            }
        }
    }

    public func getDownloadLinks(for url: URL) async throws -> [BCItemDownload] {
        let page = try await downloadService.downloadPage(at: url)
        
        let document = try HTMLDocument(data: page)
        guard let element = document.xpath("//div[@id=\"pagedata\"]").first,
              let dbStr = element.attributes["data-blob"] else {
            throw CollectionLoaderError.noData("Data blob not found")
        }
        
        let dataBlob = try JSONDecoder().decode(DownloadDataBlob.self, from: dbStr.data(using: .utf8)!)
        if dataBlob.items.count == 0 {
            throw CollectionLoaderError.noItems("No download links found in data blob from Bandcamp")
        }
        
        var links: [BCItemDownload] = []
        for (type, link) in dataBlob.items[0].downloads {
            guard let url = URL(string: link.url) else {
                logger.warning("Invalid download link: \(link.url) for \(type)")
                continue
            }
            
            guard let fileType = FileFormat(rawValue: type) else {
                logger.warning("Unknown download type: \(type)")
                continue
            }
            
            let link = BCItemDownload(format: fileType, url: url)
            links.append(link)
            
        }
        return links
    }
}

extension CollectionLoader {
    private func getDataBlob(for username: String) async throws -> DataBlob {
        if dataBlob != nil {
            return dataBlob!
        } else {
            return try await downloadDataBlob(for: username)
        }
    }
    
    private func downloadDataBlob(for username: String) async throws -> DataBlob {
        let data = try await downloadService.collectionPage(for: username)
        logger.info("Data blob size: \(data.count)bytes")
        
        let document = try HTMLDocument(data: data)
        guard let element = document.xpath("//div[@id=\"pagedata\"]").first,
              let dbStr = element.attributes["data-blob"] else {
            throw CollectionLoaderError.noData("Data blob not found")
        }
        
        let dataBlob = try JSONDecoder().decode(DataBlob.self, from: dbStr.data(using: .utf8)!)
        logger.info("Fan: \(dataBlob.fan.userId!) - \(dataBlob.collectionCount) items")
        
        return dataBlob
    }

    func downloadCollectionFor(_ fanId: Int, 
                               count: Int,
                               continuation: AsyncThrowingStream<BCItem, Error>.Continuation) async throws {

        var totalBytes = 0
        var itemCount = 0

        let startTime = DispatchTime.now()

        let data = try await downloadService.collectionData(for: fanId,
                                                            collectionLength: count)

        totalBytes += data.count
        logger.debug("data size \(data.count, privacy: .public)bytes")
        let collection = try JSONDecoder().decode(CollectionData.self, from: data)

        guard let items = collection.items else {
            continuation.finish(throwing: CollectionLoaderError.noItems("No items in collection"))
            return
        }

        if items.count == 0 {
            logger.warning("Finished collection early")
            return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM y HH:mm:ss z"
        for item in items {
            let itemId = "\(item.saleItemType)\(item.saleItemId)"
            if let download = collection.downloadUrls[itemId] {
                // 3 - 100x100
                var thumbnailUrl: URL?
                if let artUrl = item.art?.thumbnail {
                    thumbnailUrl = URL(string: artUrl)
                } else if let artId = item.artId,
                          let albumType = item.albumType {
                    thumbnailUrl = URL(string: "https://f4.bcbits.com/img/\(albumType)\(artId)_3.jpg")
                } else {
                    logger.warning("No art for \(item.bandName, privacy: .public) - \(item.itemTitle, privacy: .public)")
                }

                let added = CollectionLoader.getTimeAddedFromDates(added: item.dateAdded,
                                                                   updated: item.dateUpdated,
                                                                   purchased: item.datePurchased,
                                                                   using: formatter)

//                if (item.isPreorder ?? false) {
//                    logger.info("\(item.bandName) : \(item.itemTitle) is preorder")
//                }
                
                var tracks: [BCTrack] = []
                if let tracklists = collection.tracklists,
                   let albumType = item.albumType,
                   let albumId = item.albumId,
                   let tracklist = tracklists["\(albumType)\(albumId)"] {

                    
                    tracklist.forEach {
                        let track = BCTrack(id: $0.id,
                                            title: $0.title,
                                            artist: $0.artist,
                                            trackNumber: $0.trackNumber ?? 0,
                                            duration: $0.duration ?? 0.0,
                                            file: URL(string: $0.file.url)!)
                        tracks.append(track)
                    }
                }
                
                let modelItem = BCItem(id: item.itemId,
                                       name: item.itemTitle,
                                       artist: item.bandName,
                                       added: added,
                                       isPreorder: item.isPreorder ?? false,
                                       isHidden: item.isHidden ?? false,
                                       downloadUrl: URL(string: download)!,
                                       thumbnailUrl: thumbnailUrl,
                                       tracklist: tracks)
                continuation.yield(modelItem)
                itemCount += 1
            } else if item.itemType != .subscription {
                logger.warning("No download for \(item.bandName): \(item.itemTitle)")
            }
        }

        continuation.finish()

        let endTime = DispatchTime.now()

        let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let elapsedTimeInMilliSeconds = Double(elapsedTime) / 1_000_000.0

        logger.info("Elapsed time: \(elapsedTimeInMilliSeconds, privacy: .public)")

        logger.info("Collection has \(itemCount, privacy: .public) items")
        logger.info("Total bytes: \(totalBytes)")
    }

    static func getTimeAddedFromDates(added: String?, updated: String?, 
                                      purchased: String?,
                                      using formatter: DateFormatter) -> Int {
        var addedTime = 0
        if let added,
           let date = formatter.date(from: added) {
            addedTime = Int(date.timeIntervalSince1970)
        }

        var updatedTime = 0
        if let updated,
           let date = formatter.date(from: updated) {
            updatedTime = Int(date.timeIntervalSince1970)
        } else {
            print("Failed: \(updated ?? "<None>")")
        }

        var purchasedTime = 0
        if let purchased,
           let date = formatter.date(from: purchased) {
            purchasedTime = Int(date.timeIntervalSince1970)
        } else {
            print ("Failed: \(purchased ?? "<None>")")
        }

        return max(max(addedTime, updatedTime), purchasedTime)
    }

    public struct Photo: Decodable, Sendable {
        public let imageId: Int

        enum CodingKeys: String, CodingKey {
            case imageId = "image_id"
        }
    }

    public struct FanData: Decodable, Sendable {
        private static let imageBase = "https://f0.bcbits.com/img/" // f0 and f4 work.

        public let userId: Int?
        public let name: String?
        let photo: Photo?

        public var imageUrl: URL? {
            guard let photo else {
                return nil
            }
            return URL(string: "\(FanData.imageBase)\(photo.imageId)_42.jpg") // 42 is 50x50
        }
        
        enum CodingKeys: String, CodingKey {
            case userId = "fan_id"
            case name
            case photo
        }
    }
    
    private struct ItemArt: Decodable {
        let url: String?
        let thumbnail: String?
        
        enum CodingKeys: String, CodingKey {
            case url
            case thumbnail = "thumb_url"
        }
    }
    
    private struct Tracklist: Decodable {
        let id: Int
        let title: String
        let artist: String
        let trackNumber: Int?
        let duration: Double?
        let file: TrackStream
        
        enum CodingKeys: String, CodingKey {
            case id, title, artist, duration, file
            case trackNumber = "track_number"
        }
    }
    
    private struct TrackStream: Decodable {
        let url: String
        
        enum CodingKeys: String, CodingKey {
            case url = "mp3-v0"
        }
    }
    
    enum ItemType: String, Decodable {
        case album = "album"
        case track = "track"
        case package = "package"
        case subscription = "subscription"
    }
    
    private struct CollectionItem: Decodable {
        let userId: Int?
        let itemId: Int
        let itemType: ItemType
        let albumType: String?
        let albumId: Int?
        let bandId: Int
        let dateAdded: String?
        let dateUpdated: String?
        let datePurchased: String?

        let itemTitle: String
        let itemUrl: String
        
        let artId: Int?
        let art: ItemArt?
        
        let bandName: String
        let bandUrl: String?
        
        let saleItemId: Int
        let saleItemType: String

        let isPreorder: Bool?
        let isHidden: Bool?

        enum CodingKeys: String, CodingKey {
            case userId = "fan_id"
            case itemId = "item_id"
            case itemType = "item_type"
            case albumType = "tralbum_type"
            case albumId = "tralbum_id"
            case bandId = "band_id"
            case dateAdded = "added"
            case dateUpdated = "updated"
            case datePurchased = "purchased"
            case itemTitle = "item_title"
            case itemUrl = "item_url"
            case artId = "item_art_id"
            case art = "item_art"
            case bandName = "band_name"
            case bandUrl = "band_url"
            case saleItemId = "sale_item_id"
            case saleItemType = "sale_item_type"
            case isPreorder = "is_preorder"
            case isHidden = "hidden"
        }
    }
    
    private struct CollectionData: Decodable {
        let lastToken: String
        let downloadUrls: [String:String]
        let items: [CollectionItem]?
        let tracklists: [String: [Tracklist]]?
        let moreAvailable: Bool?
        let sequence: [String]?
        
        enum CodingKeys: String, CodingKey {
            case lastToken = "last_token"
            case downloadUrls = "redownload_urls"
            case moreAvailable = "more_available"
            case items, tracklists, sequence
        }
    }
    
    private struct ItemCache: Decodable {
        let collectionCache: [String: CollectionItem]
        // wishlist, hidden
        
        enum CodingKeys: String, CodingKey {
            case collectionCache = "collection"
        }
    }
    
    private struct DataBlob: Decodable {
        let collectionCount: Int
        let fan: FanData
        let collection: CollectionData
        let itemCache: ItemCache
        
        enum CodingKeys: String, CodingKey {
            case collectionCount = "collection_count"
            case fan = "fan_data"
            case collection = "collection_data"
            case itemCache = "item_cache"
        }
    }
    
    private struct FileInfo: Decodable {
        let url: String
    }
    
    private struct DownloadFile: Decodable {
        let downloads: [String: FileInfo]
    }
    
    private struct DownloadDataBlob: Decodable {
        let items: [DownloadFile]
        
        enum CodingKeys: String, CodingKey {
            case items = "download_items"
        }
    }
}
