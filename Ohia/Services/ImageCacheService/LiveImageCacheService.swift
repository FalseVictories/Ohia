//
//  LiveImageCacheService.swift
//  Ohia
//
//  Created by iain on 10/10/2023.
//

import AppKit
import Foundation
import OSLog
import SwiftUI

@MainActor
final class LiveImageCacheService: ImageCacheService {
    let imageCache: URLCache
    
    // Only want to log it once
    var ignoredCacheLogged = false
    
    init() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let diskCacheURL = cachesURL.appendingPathComponent("coverImages")
        
        imageCache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 1_000_000_000, directory: diskCacheURL)
        Logger.ImageService.debug("Image cache folder: \(diskCacheURL)")
    }
    
    @MainActor
    func getThumbnail(for item: OhiaItem) -> Image? {
        guard let thumbnailUrl = item.thumbnailUrl else {
            return nil
        }

        if ProcessInfo.processInfo.environment["OHIA_IGNORE_IMAGE_CACHE"] != nil {
            if !ignoredCacheLogged {
                Logger.ImageService.debug("Ignoring cache")
                ignoredCacheLogged = true
            }
            
            return nil
        }
        
        let cacheRequest = URLRequest(url: thumbnailUrl)
        if let data = imageCache.cachedResponse(for: cacheRequest)?.data {
            return LiveImageCacheService.imageFrom(data: data)
        }
        return nil
    }
    
    @MainActor
    func downloadImages(for items: [OhiaItem]) async throws {
        Logger.ImageService.info("Beginning thumbnail download for \(items.count) items")
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.urlCache = imageCache
            
            let session = URLSession(configuration: sessionConfig)
 
            // Add up to 6 download tasks
            let maxConcurrentDownloads = min(items.count, 6)
            
            for index in 0..<maxConcurrentDownloads {
                let item = items[index]
                guard let thumbnailUrl = item.thumbnailUrl else {
                    continue
                }
                
                group.addTask {
                    try await self.downloadImage(for: item,
                                                 from: thumbnailUrl,
                                                 using: session)
                }
            }
            
            var index = maxConcurrentDownloads
            while try await group.next() != nil {
                if index < items.count {
                    let item = items[index]
                    guard let thumbnailUrl = item.thumbnailUrl else {
                        continue
                    }
                    
                    group.addTask {
                        try await self.downloadImage(for: item,
                                                     from: thumbnailUrl,
                                                     using: session)
                    }
                }
                index += 1
            }
        }
        
        Logger.ImageService.info("Images downloaded")
    }
}

extension LiveImageCacheService {
    nonisolated
    private static func imageFrom(data: Data) -> Image? {
        guard let nsImage = NSImage(data: data) else {
            return nil
        }
        return Image(nsImage: nsImage)
    }
    
    nonisolated
    private func downloadImage(for item: OhiaItem,
                               from url: URL,
                               using session: URLSession) async throws {
        Logger.ImageService.debug("Downloading thumbnail for \(item.artist) - \(item.title): \(url)")
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (imageData, _) = try await session.data(for: request)
        if let image = LiveImageCacheService.imageFrom(data: imageData) {
            await item.setThumbnail(image: image)
        }
    }
}
