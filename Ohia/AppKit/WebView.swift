//
//  WebView.swift
//  Ohia
//
//  Created by iain on 08/10/2023.
//

import Dependencies
import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> some NSView {
        return webView
    }
        
    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}

protocol WebViewModelDelegate : AnyObject {
    func webViewDidLogin()
}

class WebViewModel: NSObject, ObservableObject {
    @Dependency(\.cookieService) var cookieService: any CookieService

    static let url = URL(string: "https://bandcamp.com/login")!

    let webView: WKWebView
    let cookieStore: WKHTTPCookieStore
    weak var delegate: (any WebViewModelDelegate)?

    override init() {
        webView = WKWebView()
        cookieStore = webView.configuration.websiteDataStore.httpCookieStore

        super.init()

        webView.navigationDelegate = self
        cookieStore.add(self)
    }
    
    /// Clear the current webpage to force a reload
    func clear() {
        webView.load(URLRequest(url: URL(string:"about:blank")!))
    }
    
    func loadUrl() {
        webView.load(URLRequest(url: WebViewModel.url))
    }

    func clearCookies() async {
        cookieService.clearCookies()
        for cookie in await cookieStore.allCookies() {
            await cookieStore.deleteCookie(cookie)
        }
    }
}

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.mainDocumentURL?.absoluteString {
            if url.hasSuffix(".bandcamp.com/dashboard") {
                decisionHandler(.cancel)

                delegate?.webViewDidLogin()
                return
            } else if url.hasSuffix("bandcamp.com/login") {
                decisionHandler(.allow)
                return
            }
        }

        // Need to allow Google to handle the recaptcha stuff that handles
        // the redirect
        if let url = navigationAction.request.mainDocumentURL {
            let host = url.host(percentEncoded: false)
            decisionHandler(host == "www.google.com" ? .allow : .cancel)
            return
        }
        decisionHandler(.cancel)
    }
}

extension WebViewModel: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self else {
                return
            }

            // Add cookies from WebKit to the app cookie store
            cookies.forEach {
                self.cookieService.addCookie($0)
            }
        }
    }
}

#Preview {
    WebView(webView: WebViewModel().webView)
}
