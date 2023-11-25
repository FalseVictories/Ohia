//
//  OhiaCollectionSummary.swift
//  Ohia
//
//  Created by iain on 08/11/2023.
//

import BCKit
import Foundation

struct OhiaCollectionSummary {
    let count: Int
    let mostRecentId: Int

    init(from summary: BCCollectionSummary) {
        count = summary.itemIds.count
        if let id = summary.itemIds.first {
            mostRecentId = id
        } else {
            mostRecentId = 0
        }
    }

    init(count: Int, mostRecentId: Int) {
        self.count = count
        self.mostRecentId = mostRecentId
    }

    static let invalid = OhiaCollectionSummary(count: 0, mostRecentId: 0)
}
