//
//  File.swift
//  
//
//  Created by iain on 06/10/2023.
//

import Foundation
import BCKit

final class TestDownloadService: DownloadService {
    func collectionPageFor(user: String) async throws -> Data {
        guard let fileURL = Bundle.module.url(forResource: "collectionpage", withExtension: "html") else {
            throw DownloadServiceError.noData("Missing collectionpage.html")
        }
        
        return try Data(contentsOf: fileURL)
    }
    
    func collectionDataFor(userId: Int, collectionLength: Int, lastToken: String) async throws -> Data {
        guard let fileURL = Bundle.module.url(forResource: "collection", withExtension: "json") else {
            throw DownloadServiceError.noData("Missing collection.json")
        }
        
        return try Data(contentsOf: fileURL)
    }
}
