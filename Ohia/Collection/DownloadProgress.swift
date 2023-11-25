//
//  DownloadProgress.swift
//  Ohia
//
//  Created by iain on 13/10/2023.
//

import SwiftUI

struct DownloadProgress: View {
    @ObservedObject var progress: ItemDownloadProgress
    
    var body: some View {
        VStack (alignment: .leading, spacing: 0) {
            ProgressView(value: Double(progress.bytesDownloaded), total: Double(progress.downloadSizeInBytes))
                .progressViewStyle(.linear)
            Text(DownloadProgress.progressDescription(current: progress.bytesDownloaded, total: progress.downloadSizeInBytes))
        }
    }
}

extension DownloadProgress {
    static func progressDescription(current: Int64, total: Int64) -> String {
        return "\(ByteCountFormatter.string(fromByteCount: current, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
    }
}

#Preview {
    DownloadProgress(progress: ItemDownloadProgress.preview)
}
