//
//  File.swift
//  
//
//  Created by iain on 06/10/2023.
//

import Dependencies
import Foundation

public protocol DownloadService {
    func collectionSummary() async throws -> Data
    func collectionPage(for user: String) async throws -> Data
    func collectionData(for userId: Int, collectionLength: Int) async throws -> Data
    func downloadPage(at url: URL) async throws -> Data
}

public enum DownloadServiceError: Error {
    case noData(String)
}

private enum DownloadServiceKey: DependencyKey {
    static let liveValue: any DownloadService = LiveDownloadService()
}

extension DependencyValues {
    var downloadService: any DownloadService {
        get { self[DownloadServiceKey.self] }
        set { self[DownloadServiceKey.self] = newValue }
    }
}
