//
//  LiveDownloadService.swift
//  Ohia
//
//  Created by iain on 15/10/2023.
//

import BCKit
import Foundation
import OSLog

@MainActor
final class LiveDownloadService: DownloadService {
    static let bufferSize = 65536
    static let maxDownloads = 1
    
    var downloadTask: Task<Void, Error>?
    
    func download(items: [OhiaItem],
                  ofType format: FileFormat,
                  updateClosure: @MainActor @escaping (_ item: OhiaItem,
                                                       _ filename: String?,
                                                       _ dataStream: URLSession.AsyncBytes) async throws -> Void) -> AsyncThrowingStream<(OhiaItem, Bool), Error>{
        // Print this out first so it is only printed once per download event
        // and so we don't need to await any variable later on
        if ProcessInfo().environment["OHIA_ALWAYS_FORCE_DOWNLOAD"] != nil {
            Logger.DownloadService.info("Always forcing download")
        }
        
        if downloadTask != nil {
            Logger.DownloadService.warning("Download already in progress")
            return AsyncThrowingStream.finished()
        }

        // Wrap the group inside an AsyncStream because the group only ever has `maxConcurrentDownloads` in it
        // and we can't use its AsyncSequence property to follow it
        return AsyncThrowingStream { continuation in
            downloadTask = Task {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // Limit the number of downloads to maxDownloads
                    let maxConcurrentDownloads = min(items.count, LiveDownloadService.maxDownloads)
                    
                    for index in 0..<maxConcurrentDownloads {
                        let item = items[index]
                        
                        Logger.DownloadService.debug("Adding \(item.title) to download")
                        group.addTask {
                            let result = try await self.downloadTask(for: item, 
                                                                     ofType: format,
                                                                     updateClosure: updateClosure)
                            Logger.DownloadService.debug("\(item.title) complete")
                            continuation.yield((item, result))
                        }
                    }
                    
                    var index = maxConcurrentDownloads
                    
                    // Wait for a task to complete and schedule the next download
                    while try await group.next() != nil {
                        if index < items.count {
                            let item = items[index]
                            
                            group.addTask {
                                let result = try await self.downloadTask(for: item, 
                                                                         ofType: format,
                                                                         updateClosure: updateClosure)
                                continuation.yield((item, result))
                            }
                        }
                        index += 1
                    }
                }
                
                Logger.DownloadService.debug("Downloads complete")
                // Downloads should now be finished, so nil the task
                downloadTask = nil
                continuation.finish()
            }
        }
    }
    
    func cancelDownloads() {
        downloadTask?.cancel()
        downloadTask = nil
    }
}

extension LiveDownloadService {
    nonisolated
    private func downloadTask(for item: OhiaItem,
                              ofType format: FileFormat,
                              updateClosure: (_ item: OhiaItem,
                                              _ filename: String?,
                                              _ dataStream: URLSession.AsyncBytes) async throws -> Void) async throws -> Bool {
        Logger.DownloadService.info("Downloading \(item.artist) - \(item.title)")
        
        await item.set(state: .connecting)
        
        let downloadResult = try await self.downloadItem(item, 
                                                         ofType: format,
                                                         updateClosure: updateClosure)

        Logger.DownloadService.info("Downloaded \(item.artist) - \(item.title): \(downloadResult)")
        return downloadResult
    }
    
    nonisolated
    private func write(buffer data: Data, to file: FileHandle) throws {
        try file.write(contentsOf: data)
    }
    
    nonisolated
    private func downloadItem(_ item: OhiaItem,
                              ofType format: FileFormat,
                              updateClosure: (_ item: OhiaItem,
                                              _ filename: String?,
                                              _ dataStream: URLSession.AsyncBytes) async throws -> Void) async throws -> Bool {
        let loader = CollectionLoader()
        let downloadLinks = try await loader.getDownloadLinks(for: item.downloadUrl)
        
        // Get the matching download link
        let link = downloadLinks.first {
            $0.format == format
        }
        
        guard let downloadUrl = link?.url else {
            await item.set(state: .error)
            throw DownloadServiceError.noLink("No download link for \(item.artist) - \(item.title)")
        }
        
        Logger.DownloadService.info("Downloading \(downloadUrl) \(item.artist) - \(item.title)")
        
        await item.set(state: .downloading)
        
        return try await downloadFile(for: item,
                                      from: downloadUrl,
                                      updateClosure: updateClosure)
    }
    
    nonisolated
    private func downloadFile(for item: OhiaItem,
                              from url: URL,
                              updateClosure: (_ item: OhiaItem,
                                              _ filename: String?,
                                              _ dataStream: URLSession.AsyncBytes) async throws -> Void) async throws -> Bool {
        let request = URLRequest(url: url)
        
        let (byteStream, response) = try await URLSession.shared.bytes(for: request, delegate: nil)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            await item.set(state: .error)
            throw DownloadServiceError.badResponse("Bad response for \(item.artist) - \(item.title)")
        }
        
        if (httpResponse.statusCode >= 300) {
            await item.set(state: .error)
            throw DownloadServiceError.badStatusCode("Bad status code for \(item.artist) - \(item.title): \(url.absoluteString) - \(httpResponse.statusCode)")
        }
        
        let expectedSize = httpResponse.expectedContentLength
        await item.downloadProgress.setDownloadSize(inBytes: expectedSize)
        
        let filename = httpResponse.suggestedFilename ?? "\(item.id)"
        
        await item.set(state: .downloading)
        
        try await updateClosure(item, filename, byteStream)
        
        return true
    }
}
