//
//  LiveCookieService.swift
//  Bandcamp Collection Manager
//
//  Created by iain on 02/10/2023.
//

import BinaryCodable
import BinaryCookies
import Foundation

final class LiveCookieService: CookieService {
    func getCookies() {
    }
}

final class SafariCookies {
    static let safariCookiesLocation = ["Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies", "Library/Cookies/Cookies.binarycookies"]
    
    class func loadCookies() {
        let userDir = FileManager.default.homeDirectoryForCurrentUser
        
        for location in safariCookiesLocation {
            let uri = userDir.appending(path: location)
            
            do {
                let data = try Data(contentsOf: uri)
                let cookies = try BinaryDataDecoder().decode(BinaryCookies.self, from: data)
                print("\(location)")
                print("-----------")
                dump(cookies)
            }
            catch {
                print("Error: \(String(describing: error))")
            }
        }
    }
}
