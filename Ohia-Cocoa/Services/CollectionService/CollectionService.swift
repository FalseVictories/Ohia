//
//  CollectionService.swift
//  Bandcamp Collection Manager
//
//  Created by iain on 02/10/2023.
//

import BCKit
import Dependencies
import Foundation

protocol CollectionService {
    var isLoggedIn: Bool { get }
    func listCollection() async -> CollectionModel
}

private enum CollectionServiceKey: DependencyKey {
    static let liveValue: any CollectionService = LiveCollectionService()
}

extension DependencyValues {
    var collectionService: any CollectionService {
        get { self[CollectionServiceKey.self] }
        set { self[CollectionServiceKey.self] = newValue }
    }
}


