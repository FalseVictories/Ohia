//
//  Scanner.swift
//  Ohia
//
//  Created by iain on 24/03/2024.
//

import Foundation
import OSLog

@MainActor
final class Scanner {
    var scanTask: Task<Void, Never>?
    
    func clearScanTask() {
        scanTask = nil
    }
    
    func startScan(in folder: URL,
                   resultsClosure: @escaping ([String]) throws -> Void) {
        if scanTask != nil {
            stopScan()
        }
        
        Logger.App.info("Starting scan for \(folder.path(percentEncoded: false))")
        scanTask = Task { [weak self] in
            do {
                if let results = try await self?.doScan(in: folder) {
                    try resultsClosure(results)
                }
            } catch {
                Logger.App.error("Error scanning \(folder.path(percentEncoded: false)) - \(error)")
            }
            
            self?.clearScanTask()
        }
    }
    
    func stopScan() {
        guard let scanTask else {
            return
        }
        
        Logger.App.info("Stopped scan")
        scanTask.cancel()
        self.scanTask = nil
    }
}

private extension Scanner {
    nonisolated
    func doScan(in folder: URL) throws -> [String] {
        let fm = FileManager.default
        
        let contents = try fm.contentsOfDirectory(at: folder,
                                                  includingPropertiesForKeys: nil,
                                                  options: .skipsHiddenFiles)
        
        var results = [String]()
        for url in contents {
            if url.hasDirectoryPath {
                results.append(url.lastPathComponent)
            }
        }
        
        return results
    }
    
    nonisolated
    func doScan(in folder: URL) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self else {
                    continuation.resume(returning: [])
                    return
                }
                
                do {
                    let result = try self.doScan(in: folder)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
