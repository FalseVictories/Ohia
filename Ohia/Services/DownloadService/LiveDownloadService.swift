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
    static let maxDownloads = 6
    
    var downloadTask: Task<Void, Error>?
    
    func download(items: [OhiaItem], ofType format: FileFormat, to destinationUrl: URL) -> AsyncThrowingStream<(OhiaItem, Bool), Error> {
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
                        
                        group.addTask {
                            let result = try await self.downloadTask(for: item, ofType: format, to: destinationUrl)
                            continuation.yield((item, result))
                        }
                    }
                    
                    var index = maxConcurrentDownloads
                    // Wait for a task to complete and schedule the next download
                    while try await group.next() != nil {
                        if index < items.count {
                            let item = items[index]
                            
                            group.addTask {
                                let result = try await self.downloadTask(for: item, ofType: format, to: destinationUrl)
                                continuation.yield((item, result))
                            }
                        }
                        index += 1
                    }
                }
                
                // Downloads should now be finished, so nil the task
                downloadTask = nil
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
                              to destinationUrl: URL) async throws -> Bool {
        Logger.DownloadService.info("Downloading \(item.artist) - \(item.title)")
        
        await item.set(state: .connecting)
        
        let downloadResult = try await self.downloadItem(item, ofType: format, to: destinationUrl)
        
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
                              to destinationUrl: URL) async throws -> Bool {
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
        
        return try await downloadFile(for: item, from: downloadUrl, to: destinationUrl)
    }
    
    nonisolated
    private func downloadFile(for item: OhiaItem,
                              from url: URL,
                              to destinationUrl: URL) async throws -> Bool {
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
        
        guard let fileHandle = try createFileHandle(for: filename, in: destinationUrl) else {
            return false
        }
        
        await item.set(state: .downloading)
        
        // The URLSession async data either comes as one large data block, or as individual bytes.
        // so buffer up `bufferSize` and then write that
        var buffer = Data(capacity: LiveDownloadService.bufferSize)
        var count = 0
        var totalCount = 0
        
        for try await byte in byteStream {
            // add byte to the buffer
            buffer.append(byte)
            count += 1
            totalCount += 1
            
            // write the data when the buffer is full
            if count >= LiveDownloadService.bufferSize {
                Logger.DownloadService.debug("Adding \(count) bytes to file: \(totalCount)")
                try self.write(buffer: buffer, to: fileHandle)
                
                await item.downloadProgress.increaseBytesDownloaded(size: Int64(count))
                buffer.removeAll(keepingCapacity: true)
                count = 0
            }
        }
        
        if !buffer.isEmpty {
            Logger.DownloadService.debug("Adding \(count) bytes to file: \(totalCount)")
            try self.write(buffer: buffer, to: fileHandle)
            await item.downloadProgress.increaseBytesDownloaded(size: Int64(count))
        }
        
        return true
    }
    
    nonisolated
    private func createFileHandle(for filename: String, in destinationUrl: URL) throws -> FileHandle? {
        let destinationUrl = destinationUrl.appending(path: filename, directoryHint: .notDirectory)
        let destinationPath = destinationUrl.path(percentEncoded: false)
        
        let fm = FileManager.default
        
        var overwrite = false // FIXME: Is this needed?
        if ProcessInfo().environment["OHIA_ALWAYS_FORCE_DOWNLOAD"] != nil {
            Logger.DownloadService.info("Always forcing download")
            overwrite = true
        }
        
        if fm.fileExists(atPath: destinationPath) && !overwrite {
            Logger.DownloadService.info("\(destinationPath) already exists, not overwriting")
            
            return nil
        }
        
        Logger.DownloadService.debug("Saving file as \(destinationPath)")
        
        fm.createFile(atPath: destinationPath, contents: nil, attributes: nil)
        
        return try FileHandle(forWritingTo: destinationUrl)
    }
}
