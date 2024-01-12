//
//  DownloaderService.swift
//  Ohia
//
//  Created by iain on 15/10/2023.
//

import BCKit
import Dependencies
import Foundation

struct DownloadOptions {
    let decompress: Bool
    let createFolder: Bool
    let overwrite: Bool
}

protocol DownloadService {
    @MainActor
    func download(items: [OhiaItem],
                  ofType format: FileFormat,
                  updateClosure: @MainActor @escaping (_ item: OhiaItem,
                                                       _ filename: String?,
                                                       _ dataStream: URLSession.AsyncBytes) async throws -> Void) -> AsyncThrowingStream<(OhiaItem, Bool), Error>

    @MainActor
    func cancelDownloads()
}

public enum DownloadServiceError: Error {
    case noLink(String)
    case badResponse(String)
    case badStatusCode(String)
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
