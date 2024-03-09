//
//  ImageCache.swift
//  Ohia
//
//  Created by iain on 10/10/2023.
//

import Dependencies
import Foundation
import SwiftUI

protocol ImageCacheService: Sendable {
    @MainActor
    func getThumbnail(for item: OhiaItem) -> Image?
    func downloadImages(for items: [OhiaItem]) async throws
}

@MainActor
private enum ImageCacheServiceKey: DependencyKey {
    static let liveValue: any ImageCacheService = LiveImageCacheService()
}

extension DependencyValues {
    var imageCacheService: any ImageCacheService {
        get { self[ImageCacheServiceKey.self] }
        set { self[ImageCacheServiceKey.self] = newValue }
    }
}
