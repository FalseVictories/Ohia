//
//  LiveCookieService.swift
//  Ohia
//
//  Created by iain on 25/11/2023.
//

import Foundation

class LiveCookieService: CookieService {
    static let bandcampCookieDomain = ".bandcamp.com"
    static let loggedInCookieName = "js_logged_in"

    var isLoggedIn: Bool {
        if ProcessInfo().environment["OHIA_ALWAYS_LOG_IN"] != nil {
            clearCookies()
        }

        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return false
        }

        for cookie in cookies {
            if cookie.domain == LiveCookieService.bandcampCookieDomain &&
                cookie.name == LiveCookieService.loggedInCookieName {
                return true
            }
        }

        return false
    }

    func clearCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return
        }

        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    func addCookie(_ cookie: HTTPCookie) {
        HTTPCookieStorage.shared.setCookie(cookie)
    }
}
