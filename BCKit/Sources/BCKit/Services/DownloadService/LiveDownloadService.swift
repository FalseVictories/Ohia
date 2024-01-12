//
//  File.swift
//  
//
//  Created by iain on 06/10/2023.
//

import Foundation

final class LiveDownloadService: DownloadService {
    static let collectionPostUrl = URL(string:"https://bandcamp.com/api/fancollection/1/collection_items")!
    static let collectionSummaryUrl = URL(string:"https://bandcamp.com/api/fan/2/collection_summary")!
    static let fanUrl = URL(string:"https://bandcamp.com/api/")
    
    func collectionSummary() async throws -> Data {
        var request = URLRequest(url: LiveDownloadService.collectionSummaryUrl)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = true
        
        let data = try await data(for: request)
        return data
    }
    
    func collectionPage(for user: String) async throws -> Data {
        let url = URL(string: "https://bandcamp.com/\(user)")!
        return try await downloadPage(at: url)
    }
    
    func collectionData(for userId: Int, collectionLength: Int) async throws -> Data {
        var request = URLRequest(url: LiveDownloadService.collectionPostUrl)
        request.httpMethod = "POST"
        
        // older_than_token is formatted in 5 parts separated with :
        // 1:2:3:4:5
        // 1: unix timestamp of last item (or current time)
        // 2: tralbum_id of last item (can be blank)
        // 3: tralbum_type
        // 4: number of items after last item
        // 5: unknown/unused
        //
        // For our purposes "currentTime::a::" is sufficient to get all items ever
        let parameters: [String: Any] = [
            "fan_id": userId,
            "count": collectionLength,
            "older_than_token": "\(Date.now.timeIntervalSince1970)::a::"]
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        return try await data(for: request)
    }
    
    func downloadPage(at url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = true
        
        return try await data(for: request)
    }
}

extension LiveDownloadService {
    private func data(for request: URLRequest) async throws -> Data {
        // FIXME: Check and handle failures on the request
        let (data, _) = try await URLSession.shared.data(for: request)

        return data
    }
}
