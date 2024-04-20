//
//  DownloaderService.swift
//  Ohia
//
//  Created by iain on 15/10/2023.
//

import BCKit
import Dependencies
import Foundation
import Packet

struct DownloadServiceOptions {
    let format: FileFormat
    let maxDownloads: Int
}

typealias DownloadUpdater = @MainActor @Sendable (OhiaItem, 
                                                  String?,
                                                  AsyncThrowingDataChunks) async throws -> Void
protocol DownloadService: Sendable {
    @MainActor
    func download(items: [OhiaItem],
                  with options: DownloadServiceOptions,
                  updateClosure: @escaping DownloadUpdater) -> AsyncStream<(OhiaItem, (any Error)?)>

    @MainActor
    func cancelDownloads()
}

public enum DownloadServiceError: Error {
    case noLink(String)
    case badResponse(String)
    case badStatusCode(String)
}

extension DownloadServiceError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .badResponse(let msg):
            return msg
            
        case .badStatusCode(let msg):
            return msg
            
        case.noLink(let msg):
            return msg
        }
    }
}

@MainActor
private enum DownloadServiceKey: DependencyKey {
    static let liveValue: any DownloadService = LiveDownloadService()
}

extension DependencyValues {
    var downloadService: any DownloadService {
        get { self[DownloadServiceKey.self] }
        set { self[DownloadServiceKey.self] = newValue }
    }
}
