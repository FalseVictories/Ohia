//
//  ItemDownloadProgress.swift
//  Ohia
//
//  Created by iain on 15/10/2023.
//

import Foundation

@MainActor
final class ItemDownloadProgress: ObservableObject {
    @Published var progress = 0.0
    @Published var bytesDownloaded: Int64 = 0
    
    var downloadSizeInBytes: Int64 = 0

    func increaseBytesDownloaded(size: Int64) {
        bytesDownloaded += size
        if downloadSizeInBytes != 0 {
            progress = Double(bytesDownloaded) / Double(downloadSizeInBytes)
        }
    }
    
    func setDownloadSize(inBytes size: Int64) {
        downloadSizeInBytes = size
    }
    static let preview = ItemDownloadProgress()
}
