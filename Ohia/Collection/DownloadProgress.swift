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
            ProgressView(value: Double(progress.progress), total: Double(100))
                .progressViewStyle(.linear)
            Text(DownloadProgress.progressDescription(current: progress.bytesDownloaded, total: progress.downloadSizeString))
        }
    }
}

extension DownloadProgress {
    static func progressDescription(current: Int64, total: String) -> String {
        return "\(ByteCountFormatter.string(fromByteCount: current, countStyle: .file)) / \(total)"
    }
}

#Preview {
    DownloadProgress(progress: ItemDownloadProgress.preview)
}
