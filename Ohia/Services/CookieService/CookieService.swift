//
//  CookieService.swift
//  Ohia
//
//  Created by iain on 25/11/2023.
//

import Dependencies
import Foundation

protocol CookieService {
    var isLoggedIn: Bool { get }

    func clearCookies()
    func addCookie(_ cookie: HTTPCookie)
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
