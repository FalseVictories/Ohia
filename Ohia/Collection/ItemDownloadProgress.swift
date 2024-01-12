//
//  ItemDownloadProgress.swift
//  Ohia
//
//  Created by iain on 15/10/2023.
//

import Foundation
import OSLog

@MainActor
final class ItemDownloadProgress: ObservableObject {
    @Published var progress = 0.0
    @Published var bytesDownloaded: Int64 = 0
    
    var destinationUrl: URL?
    var fileHandle: FileHandle?
    
    var downloadSizeInBytes: Int64 = 0
    
    static let preview = ItemDownloadProgress()
}

extension ItemDownloadProgress {
    func increaseBytesDownloaded(size: Int64) {
        bytesDownloaded += size
        if downloadSizeInBytes != 0 {
            progress = Double(bytesDownloaded) / Double(downloadSizeInBytes)
        }
    }
    
    func setDownloadSize(inBytes size: Int64) {
        downloadSizeInBytes = size
    }
    
    func setDestinationUrl(_ url: URL) {
        destinationUrl = url
    }
    
    func startWritingDataFor(_ filename: String,
                             in destinationUrl: URL,
                             with options: DownloadOptions) throws -> FileHandle?
    {
        let fileHandle = try createFileHandle(for: filename, 
                                              in: destinationUrl,
                                              with: options)
        return fileHandle
    }
    
    nonisolated
    func startDecompressing(to destinationUrl: URL) async -> Zipper {
        await setDestinationUrl(destinationUrl)
        let zipper = Zipper()
        zipper.delegate = self
        return zipper
    }
}

private extension ItemDownloadProgress {
    private func createFileHandle(for filename: String,
                                  in destinationUrl: URL,
                                  with options: DownloadOptions) throws -> FileHandle? {
        let destinationUrl = destinationUrl.appending(path: filename, directoryHint: .notDirectory)
        let destinationPath = destinationUrl.path(percentEncoded: false)
        
        let fm = FileManager.default
        
        var overwrite = options.overwrite
        if ProcessInfo().environment["OHIA_ALWAYS_FORCE_DOWNLOAD"] != nil {
            Logger.Download.info("Always forcing download")
            overwrite = true
        }

        if fm.fileExists(atPath: destinationPath) && !overwrite {
            Logger.Download.info("\(destinationPath) already exists, not overwriting")
            
            return nil
        }
        
        Logger.Download.debug("Saving file as \(destinationPath)")
        
        fm.createFile(atPath: destinationPath, contents: nil, attributes: nil)
        
        return try FileHandle(forWritingTo: destinationUrl)
    }
}

extension ItemDownloadProgress: ZipperDelegate {
    func createFolder(with name: String) {
        guard let destinationUrl else {
            Logger.Model.error("No destination URL set")
            return
        }
        
        let fm = FileManager.default
        
        var isDirectory = ObjCBool(false)
        let destFolder = destinationUrl.appending(path: name, directoryHint: .isDirectory)
        
        if fm.fileExists(atPath: destFolder.path(percentEncoded: false), isDirectory: &isDirectory) {
            Logger.Download.warning("\(destFolder.path(percentEncoded: false)) already exists (\(isDirectory.boolValue))")
            // FIXME: Handle exists
            return
        }
        
        do {
            try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)
        } catch {
            Logger.Download.error("Error creating \(destFolder.path(percentEncoded: false)): \(error)")
            return
        }
    }
    
    func beginWritingFile(with name: String) {
        if fileHandle == nil,
           let destinationUrl {
            do {
                // FIXME: Get the correct download options here
                fileHandle = try createFileHandle(for: name,
                                                  in: destinationUrl, 
                                                  with: DownloadOptions(decompress: true,
                                                                        createFolder: true,
                                                                        overwrite: false))
            } catch {
                Logger.Download.error("Error creating file handle for \(name): \(error)")
            }
        }
    }
    
    func writeData(from buffer: Data) {
        guard let fileHandle else {
            return
        }
        
        do {
            Logger.Download.debug("Writing \(buffer.count) bytes")
            try fileHandle.write(contentsOf: buffer)
        } catch {
            Logger.Download.error("Error writing data: \(error)")
        }
    }
    
    func endWritingFile() {
        do {
            Logger.Download.info("Closing file handle")
            try fileHandle?.close()
        } catch {
            Logger.Download.error("Error closing file: \(error)")
        }
        
        fileHandle = nil
    }
    
    func errorDidOccur(_ error: ZipperError) {
        Logger.Download.error("Zipper error: \(error)")
    }
}
