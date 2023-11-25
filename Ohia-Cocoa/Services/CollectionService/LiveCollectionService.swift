//
//  LiveCollectionService.swift
//  Bandcamp Collection Manager
//
//  Created by iain on 02/10/2023.
//

import BCKit
import Foundation
import OSLog


final class LiveCollectionService: CollectionService {
    static let bandcampCookieDomain = ".bandcamp.com"
    static let loggedInCookieName = "js_logged_in"
    
    var isLoggedIn: Bool {
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return false
        }
        
        for cookie in cookies {
            if cookie.domain == LiveCollectionService.bandcampCookieDomain &&
                cookie.name == LiveCollectionService.loggedInCookieName {
                return true
            }
        }
        
        return false
    }

    func listCollection() async -> CollectionModel {
        let loader = CollectionLoader()
        return await loader.listCollectionFor(username: "xxiainxx")
    }
}
