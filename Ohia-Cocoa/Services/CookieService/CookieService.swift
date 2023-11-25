//
//  CookieService.swift
//  Bandcamp Collection Manager
//
//  Created by iain on 02/10/2023.
//

import Dependencies
import Foundation

protocol CookieService {
    func getCookies()
}

private enum CookieServiceKey: DependencyKey {
    static let liveValue: any CookieService = LiveCookieService()
}

extension DependencyValues {
    var cookieService: any CookieService {
        get { self[CookieServiceKey.self] }
        set { self[CookieServiceKey.self] = newValue }
    }
}

