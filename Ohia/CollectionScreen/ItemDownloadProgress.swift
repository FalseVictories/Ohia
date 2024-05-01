//
//  ItemDownloadProgress.swift
//  Ohia
//
//  Created by iain on 15/10/2023.
//

import Foundation
import OSLog
import Zipper

@MainActor
final class ItemDownloadProgress: ObservableObject {
    @Published var progress = 0
    @Published var bytesDownloaded: Int64 = 0
    
    var byteCounter: Int64 = 0
    
    var destinationUrl: URL?
    var downloadOptions: DownloadOptions?
    var fileHandle: FileHandle?
    
    var downloadSizeInBytes: Int64 = 0
    var downloadSizeString: String = ""
    
    static let preview = ItemDownloadProgress()
}

extension ItemDownloadProgress {
    func increaseBytesDownloaded(size: Int64) {
        byteCounter += size
        
        // Use byteCounter to reduce the number of updates to bytesDownloaded
        if byteCounter > 250_000 {
            bytesDownloaded += byteCounter
            byteCounter = 0
        }
        
        if downloadSizeInBytes != 0 {
            progress = Int((Double(bytesDownloaded) / Double(downloadSizeInBytes)) * 100)
        }
    }
    
    func setBytesDownloaded(_ bytes: Int64) {
        // Use byteCounter to reduce the number of updates to bytesDownloaded
        byteCounter = bytes
        if byteCounter - bytesDownloaded > 250_000 {
            bytesDownloaded = byteCounter
        }
        
        if downloadSizeInBytes != 0 {
            progress = Int((Double(bytesDownloaded) / Double(downloadSizeInBytes)) * 100)
        }
    }
    
    func setDownloadSize(inBytes size: Int64) {
        downloadSizeInBytes = size
        downloadSizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    func setDestinationUrl(_ url: URL, options: DownloadOptions) {
        destinationUrl = url
        downloadOptions = options
    }
    
    func startWritingDataFor(_ filename: String,
                             in destinationUrl: URL,
                             with options: DownloadOptions) -> Result<FileHandle?, Error>
    {
        do {
            let fileHandle = try createFileHandle(for: filename,
                                                  in: destinationUrl,
                                                  with: options)
            return Result.success(fileHandle)
        } catch {
            return Result.failure(error)
        }
    }
    
    func startDecompressing(to destinationUrl: URL,
                            with options: DownloadOptions) -> Zipper {
        let zipperDelegate = ZipperDelegate(createFolder: createFolder(with:),
                                            beginWritingFile: beginWritingFile(with:),
                                            writeData: writeData(from:bytesDownloaded:),
                                            endWritingFile: endWritingFile,
                                            didFinish: didFinish,
                                            errorDidOccur: errorDidOccur(_:))
        setDestinationUrl(destinationUrl, options: options)
        
        let zipper = Zipper(delegate: zipperDelegate)
        return zipper
    }
}

private extension ItemDownloadProgress {
    private func createFileHandle(for filename: String,
                                  in destinationUrl: URL,
                                  with options: DownloadOptions) throws -> FileHandle? {
        let finalDestinationUrl = destinationUrl.appending(path: filename)
        let finalPath = finalDestinationUrl.path(percentEncoded: false)
        let destinationUrl = destinationUrl.appending(path: filename + ".ohia-download",
                                                      directoryHint: .notDirectory)
        let destinationPath = destinationUrl.path(percentEncoded: false)
        
        let fm = FileManager.default
        
        var overwrite = options.overwrite
        if ProcessInfo().environment["OHIA_ALWAYS_FORCE_DOWNLOAD"] != nil {
            Logger.Download.info("Always forcing download")
            overwrite = true
        }

        if fm.fileExists(atPath: finalPath) && !overwrite {
            Logger.Download.info("\(finalPath) already exists, not overwriting")
            return nil
        }
        
        if fm.fileExists(atPath: destinationPath) {
            Logger.Download.debug("Partial \(destinationPath) exists: removing")
            try fm.removeItem(atPath: destinationPath)
        }
        
        Logger.Download.debug("Saving file as \(destinationPath)")
        
        fm.createFile(atPath: destinationPath, contents: nil, attributes: nil)
        
        return try FileHandle(forWritingTo: destinationUrl)
    }
    
    func createFolder(with name: String) {
        guard let destinationUrl else {
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
        guard let destinationUrl,
              let downloadOptions else {
            return
        }
        
        if fileHandle == nil {
            do {
                // FIXME: Get the correct download options here
                fileHandle = try createFileHandle(for: name,
                                                  in: destinationUrl,
                                                  with: downloadOptions)
            } catch {
                Logger.Download.error("Error creating file handle for \(name): \(error)")
            }
        }
    }

    func writeData(from buffer: Data,
                   bytesDownloaded: Int64) {
        guard let fileHandle else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.increaseBytesDownloaded(size: Int64(buffer.count))
        }
        
        do {
            try fileHandle.write(contentsOf: buffer)
        } catch {
            Logger.Download.error("Error writing data: \(error)")
        }
    }
    
    func endWritingFile(filename: String) {
        do {
            Logger.Download.info("Closing file handle")
            try fileHandle?.close()
            
            guard let destinationUrl else {
                Logger.Download.debug("No destination")
                return
            }
            
            let destPath = destinationUrl.path(percentEncoded: false) + "/" + filename
            let inProgressPath = destPath + ".ohia-download"
            
            Logger.Download.debug("Renaming \(inProgressPath) to \(destPath)")
            try FileManager.default.moveItem(atPath: inProgressPath, toPath: destPath)
        } catch {
            Logger.Download.error("Error closing file: \(error)")
        }
        
        fileHandle = nil
    }
    
    func didFinish() {
        Logger.Download.info("Finished extracting")
    }
    
    func errorDidOccur(_ error: ZipperError) {
        Logger.Download.error("Zipper error: \(error)")
    }
}
